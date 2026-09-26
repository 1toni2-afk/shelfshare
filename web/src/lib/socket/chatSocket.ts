import { io, type Socket } from 'socket.io-client';
import { api, API_BASE_URL } from '@/lib/api/client';
import { tokenStorage } from '@/lib/api/client';

/** Cât așteptăm handshake-ul (transport + autentificare + join în cameră). */
const CONNECT_TIMEOUT_MS = 15_000;

/**
 * Wrapper peste socket.io pentru namespace-ul `/chat`. Un singur socket pentru
 * toată aplicația. Port al chat_socket_service.dart, inclusiv capcanele lui.
 */
class ChatSocket {
  private socket: Socket | null = null;
  private connecting: Promise<Socket> | null = null;

  get isConnected(): boolean {
    return this.socket?.connected ?? false;
  }

  connect(): Promise<Socket> {
    if (this.socket?.connected) return Promise.resolve(this.socket);
    this.connecting ??= this.doConnect().finally(() => {
      this.connecting = null;
    });
    return this.connecting;
  }

  /**
   * Pornește conexiunea fără ca apelantul să aștepte handshake-ul și fără ca un
   * eșec să se propage.
   *
   * Listele (conversații, notificări, schimburi) NU trebuie să aștepte socketul
   * înainte de fetch-ul HTTP. Socketul e doar pentru actualizări live; datele
   * vin pe HTTP, care merge independent. Cu `await`, un handshake care nu se
   * stabilea ținea lista în „se încarcă" 15 secunde și apoi o arunca în eroare,
   * deși API-ul răspundea perfect - și, fiindcă toate așteptau ACEEAȘI promisiune,
   * un singur handshake căzut le strica pe toate deodată.
   */
  connectInBackground(): void {
    this.connect().catch((error: unknown) => {
      // Nimic de făcut: socket.io reîncearcă singur, iar listele s-au încărcat
      // deja pe HTTP. Doar notăm, ca să nu rămână o respingere neprinsă.
      console.warn('[socket] conectare eșuată (actualizările live sunt oprite):', error);
    });
  }

  /**
   * Închide conexiunea acum, fără reconectare automată - folosit la logout.
   *
   * Fără ea, socketul vechi rămâne deschis cu tokenul contului precedent:
   * serverul continuă să-l vadă pe userul respectiv „online" până expiră
   * tokenul, iar prezența devine o minciună.
   */
  disconnect(): void {
    this.socket?.disconnect();
    this.socket?.removeAllListeners();
    this.socket = null;
    this.connecting = null;
  }

  private async doConnect(): Promise<Socket> {
    // Fără token, gateway-ul respinge conexiunea și nu emite niciodată 'ready',
    // deci am aștepta degeaba tot timeout-ul. Se întâmplă la fiecare pornire
    // cât timp userul e pe ecranul de login.
    const token = await tokenStorage.getAccessToken();
    if (!token) throw new Error('Socket fără sesiune: nu există access token.');

    // Socketul anterior trebuie desființat EXPLICIT, nu doar abandonat:
    // socket.io are reconectare automată proprie, iar unul abandonat continuă
    // să reîncerce în fundal și poate reuși DUPĂ ce i-am scos ascultătorii.
    this.socket?.disconnect();
    this.socket?.removeAllListeners();

    const socket = io(`${API_BASE_URL}/chat`, {
      // Polling PRIMUL, nu websocket. Dacă websocket eșuează (exact ce face un
      // proxy sau un tunel care blochează upgrade-ul WS), engine.io NU mai
      // încearcă polling - `tryAllTransports` e false implicit - iar socketul
      // rămâne mort, fără nicio eroare vizibilă.
      //
      // Aici nu se aplică restricția din Flutter (unde pe mobil transportul e
      // mereu WebSocket, indiferent ce se cere): sub Capacitor rulează tot
      // engine.io de browser, deci și Android, și iOS, și web folosesc aceeași
      // listă. Motiv în plus să nu o „optimizăm" la websocket-only.
      transports: ['polling', 'websocket'],
      autoConnect: false,
      // Funcție, nu obiect static: se apelează din nou la fiecare (re)conectare,
      // inclusiv la reconectările automate. Cu un token fix, expirarea lui
      // (15 minute) ar face ca orice reconectare ulterioară să retrimită la
      // infinit același token mort, fără nicio eroare vizibilă - mesajele pur
      // și simplu n-ar mai ajunge.
      auth: (callback: (data: Record<string, unknown>) => void) => {
        void api
          .ensureFreshToken()
          .then(() => tokenStorage.getAccessToken())
          .then((fresh) => callback({ token: fresh }))
          // Fără callback, handshake-ul atârnă la nesfârșit. Mai bine un token
          // vechi respins curat decât o conexiune care nu se termină niciodată.
          .catch(() => callback({ token }));
      },
    });

    this.socket = socket;

    return new Promise<Socket>((resolve, reject) => {
      const timer = window.setTimeout(() => {
        cleanup();
        // Altfel socketul ratat rămâne în fundal reîncercând la nesfârșit.
        socket.disconnect();
        socket.removeAllListeners();
        if (this.socket === socket) this.socket = null;
        reject(new Error('Socket: handshake expirat'));
      }, CONNECT_TIMEOUT_MS);

      function cleanup() {
        window.clearTimeout(timer);
        socket.off('ready', onReady);
      }

      function onReady() {
        cleanup();
        resolve(socket);
      }

      // Așteptăm 'ready' (emis de server DUPĂ ce a terminat join-ul pe camera
      // user:<id>), nu simplul 'connect'. 'connect' se declanșează la finalul
      // handshake-ului, înainte ca handler-ul async de pe server să termine
      // join-ul: un eveniment emis chiar în acea fereastră (o notificare
      // primită imediat după login) s-ar pierde în tăcere, fiindcă socketul
      // încă nu e în cameră.
      socket.on('ready', onReady);

      // NU respingem la primul `connect_error`: socket.io reîncearcă singur cu
      // backoff, iar 2-3 tentative eșuate pe primul handshake printr-un tunel
      // sunt normale. Singura cale de eșec rămâne timeout-ul de mai sus.
      socket.on('connect_error', (error) => {
        console.warn('[socket] connect_error:', error.message);
      });

      socket.connect();
    });
  }

  /** Ascultă un eveniment; întoarce funcția de dezabonare. */
  on<T = unknown>(event: string, handler: (payload: T) => void): () => void {
    // Legăm pe socketul CURENT dacă există, altfel îl pornim. `doConnect`
    // atribuie `this.socket` înainte de a aștepta 'ready', deci apelantul poate
    // lega ascultătorii imediat după `connectInBackground()`.
    this.connectInBackground();
    this.socket?.on(event, handler as (...args: unknown[]) => void);
    return () => {
      this.socket?.off(event, handler as (...args: unknown[]) => void);
    };
  }

  /** Emite cu confirmare de la server (send_message, mark_read, join). */
  async emitWithAck<T>(event: string, payload: unknown): Promise<T> {
    const socket = await this.connect();
    return socket.timeout(8000).emitWithAck(event, payload) as Promise<T>;
  }

  /** Emite fără confirmare (typing) - pierderea lui nu schimbă nimic. */
  emit(event: string, payload: unknown): void {
    this.socket?.emit(event, payload);
  }

  joinConversation(conversationId: string) {
    return this.emitWithAck<{ joined?: string; otherUserOnline?: boolean; error?: string }>(
      'join_conversation',
      conversationId,
    );
  }

  markRead(conversationId: string) {
    return this.emitWithAck<{ markedCount: number }>('mark_read', conversationId);
  }

  typing(conversationId: string): void {
    this.emit('typing', conversationId);
  }
}

export const chatSocket = new ChatSocket();
