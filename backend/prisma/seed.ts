/**
 * Populeaza baza de date cu date demo: utilizatori, carti, biblioteci
 * personale, cereri de schimb (istoric complet - PENDING/ACCEPTED/
 * REJECTED/CANCELLED/COMPLETED), conversatii+mesaje, wishlist si
 * notificari. Scop: sa arate ca o aplicatie deja folosita, nu goala.
 *
 * Ruleaza in interiorul containerului backend (DATABASE_URL rezolva
 * "postgres" ca host doar acolo):
 *   docker compose exec backend pnpm exec ts-node prisma/seed.ts
 */
import 'dotenv/config';
import {
  PrismaClient,
  BookCondition,
  ExchangeStatus,
  User,
  Book,
  UserBook,
  ExchangeRequest,
} from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

type UserBookWithMeta = UserBook & { ownerId: string; bookTitle: string };
type ExchangeWithMeta = ExchangeRequest & { bookTitle: string };

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const DEMO_PASSWORD = 'Parola123!';

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickSeeded<T>(arr: T[], seed: number): T {
  return arr[seed % arr.length];
}

const USERS = [
  { name: 'Andrei Popescu', city: 'București', bio: 'Pasionat de SF și fantasy, citesc cam o carte pe săptămână.' },
  { name: 'Maria Ionescu', city: 'Cluj-Napoca', bio: 'Îmi place literatura română clasică și poezia.' },
  { name: 'Ștefan Dumitru', city: 'Timișoara', bio: 'Colecționez cărți de dezvoltare personală și biografii.' },
  { name: 'Elena Constantin', city: 'Iași', bio: 'Cititoare împătimită de thriller și crime fiction.' },
  { name: 'Radu Georgescu', city: 'Brașov', bio: 'Dau la schimb cărți de istorie și non-ficțiune.' },
  { name: 'Ioana Marin', city: 'Constanța', bio: 'Îmi plac cărțile pentru copii - am doi copii mici.' },
  { name: 'Alexandru Stan', city: 'Craiova', bio: 'Fan Tolkien și Rowling, mereu în căutare de fantasy bun.' },
  { name: 'Cristina Voicu', city: 'Sibiu', bio: 'Citesc orice, dar prefer clasicii internaționali.' },
  { name: 'Mihai Radu', city: 'Oradea', bio: 'Pasionat de SF hard și distopii.' },
  { name: 'Ana Munteanu', city: 'Ploiești', bio: 'Îmi place să descopăr autori noi prin schimburi.' },
  { name: 'Vlad Nistor', city: 'Galați', bio: 'Biografii, memorii și cărți de business.' },
  { name: 'Diana Enache', city: 'Târgu Mureș', bio: 'Cititoare de weekend, prefer romane contemporane.' },
  { name: 'George Toma', city: 'Bacău', bio: 'Colecționez ediții vechi și cărți de istorie.' },
  { name: 'Simona Pavel', city: 'Arad', bio: 'Fantasy și YA - mereu deschisă la schimburi.' },
  { name: 'Bogdan Iliescu', city: 'Sfântu Gheorghe', bio: 'Citesc mai ales seara, thriller și SF.' },
  { name: 'Laura Barbu', city: 'Suceava', bio: 'Carti pentru copii si literatura romana - schimb des.' },
];

const BOOKS = [
  { title: 'Ion', author: 'Liviu Rebreanu', isbn: null, genre: 'Clasic românesc', publishedYear: 1920, language: 'Română', pageCount: 480, description: 'Romanul lui Ion al Glanetașului, ros de setea de pământ, într-un sat ardelenesc de la începutul secolului XX.' },
  { title: 'Enigma Otiliei', author: 'George Călinescu', isbn: null, genre: 'Clasic românesc', publishedYear: 1938, language: 'Română', pageCount: 480, description: 'Bucureștiul burghez de la 1900, moștenirea lui moș Costache și tânăra Otilia, privite prin ochii adolescentului Felix.' },
  { title: 'Moromeții', author: 'Marin Preda', isbn: null, genre: 'Clasic românesc', publishedYear: 1955, language: 'Română', pageCount: 400, description: 'Familia lui Ilie Moromete, în satul câmpiei dunărene, în anii dinaintea celui de-Al Doilea Război Mondial.' },
  { title: 'Baltagul', author: 'Mihail Sadoveanu', isbn: null, genre: 'Clasic românesc', publishedYear: 1930, language: 'Română', pageCount: 200, description: 'Vitoria Lipan pornește să afle ce s-a întâmplat cu soțul ei dispărut, urmând drumul turmelor prin munți.' },
  { title: 'Craii de Curtea-Veche', author: 'Mateiu Caragiale', isbn: null, genre: 'Clasic românesc', publishedYear: 1929, language: 'Română', pageCount: 160, description: 'O lume decadentă de aristocrați scăpătați, în Bucureștiul nopților lungi de la începutul secolului XX.' },
  { title: 'Amintiri din copilărie', author: 'Ion Creangă', isbn: null, genre: 'Clasic românesc', publishedYear: 1892, language: 'Română', pageCount: 220, description: 'Copilăria lui Nică a lui Ștefan a Petrei la Humulești, povestită cu umor și limbaj viu, popular.' },
  { title: '1984', author: 'George Orwell', isbn: '9780451524935', genre: 'Distopie', publishedYear: 1949, language: 'Engleză', pageCount: 328, description: 'Winston Smith trăiește sub supravegherea permanentă a Fratelui cel Mare, într-un stat totalitar care rescrie trecutul.' },
  { title: 'Crimă și pedeapsă', author: 'Feodor Dostoievski', isbn: '9780486415871', genre: 'Clasic', publishedYear: 1866, language: 'Română', pageCount: 671, description: 'Studentul Raskolnikov comite o crimă și se zbate apoi în vinovăție, în Sankt Petersburgul sărăciei și disperării.' },
  { title: 'Micul Prinț', author: 'Antoine de Saint-Exupéry', isbn: '9780156012195', genre: 'Ficțiune', publishedYear: 1943, language: 'Română', pageCount: 96, description: 'Un aviator prăbușit în deșert întâlnește un mic prinț venit de pe o planetă îndepărtată, cu o singură floare.' },
  { title: 'Harry Potter și Piatra Filosofală', author: 'J.K. Rowling', isbn: '9780747532699', genre: 'Fantasy', publishedYear: 1997, language: 'Română', pageCount: 320, description: 'Un băiat orfan descoperă la 11 ani că e vrăjitor și pleacă la Hogwarts, școala de magie.' },
  { title: 'Stăpânul Inelelor: Frăția Inelului', author: 'J.R.R. Tolkien', isbn: '9780618346257', genre: 'Fantasy', publishedYear: 1954, language: 'Română', pageCount: 423, description: 'Hobbitul Frodo pornește cu un inel al puterii spre Muntele Osândei, alături de o frăție de nouă tovarăși.' },
  { title: 'Jocurile Foamei', author: 'Suzanne Collins', isbn: '9780439023528', genre: 'SF', publishedYear: 2008, language: 'Română', pageCount: 374, description: 'Într-un viitor distopic, Katniss Everdeen se oferă voluntar pentru un turneu televizat pe viață și pe moarte.' },
  { title: 'Leul, Vrăjitoarea și Dulapul', author: 'C.S. Lewis', isbn: '9780064404990', genre: 'Fantasy', publishedYear: 1950, language: 'Română', pageCount: 206, description: 'Patru frați descoperă, printr-un dulap vechi, tărâmul fermecat și înghețat al Narniei.' },
  { title: 'Sapiens: Scurtă istorie a omenirii', author: 'Yuval Noah Harari', isbn: '9780062316097', genre: 'Non-ficțiune', publishedYear: 2011, language: 'Română', pageCount: 443, description: 'O trecere în revistă a istoriei speciei umane, de la triburile de vânători-culegători la civilizația modernă.' },
  { title: 'Atomic Habits', author: 'James Clear', isbn: '9780735211292', genre: 'Dezvoltare personală', publishedYear: 2018, language: 'Engleză', pageCount: 320, description: 'Un ghid practic despre cum schimbări mici și constante în obiceiuri produc rezultate mari pe termen lung.' },
  { title: 'Alchimistul', author: 'Paulo Coelho', isbn: '9780062315007', genre: 'Ficțiune', publishedYear: 1988, language: 'Română', pageCount: 208, description: 'Un cioban andaluz pornește spre piramidele Egiptului în căutarea unei comori visate, descoperindu-și menirea.' },
  { title: 'Să ucizi o pasăre cântătoare', author: 'Harper Lee', isbn: '9780061120084', genre: 'Clasic', publishedYear: 1960, language: 'Română', pageCount: 336, description: 'Fetița Scout povestește copilăria din sudul american segregaționist și procesul apărat de tatăl ei, avocat.' },
  { title: 'Mândrie și prejudecată', author: 'Jane Austen', isbn: '9780141439518', genre: 'Clasic', publishedYear: 1813, language: 'Română', pageCount: 432, description: 'Elizabeth Bennet și domnul Darcy își depășesc mândria și prejudecățile reciproce, în Anglia rurală de secol XIX.' },
  { title: 'Hobbitul', author: 'J.R.R. Tolkien', isbn: '9780547928227', genre: 'Fantasy', publishedYear: 1937, language: 'Română', pageCount: 310, description: 'Hobbitul Bilbo Baggins e atras într-o aventură neașteptată alături de pitici, spre comoara păzită de dragonul Smaug.' },
  { title: 'Dune', author: 'Frank Herbert', isbn: '9780441013593', genre: 'SF', publishedYear: 1965, language: 'Engleză', pageCount: 412, description: 'Pe planeta deșertică Arrakis, tânărul Paul Atreides se confruntă cu politică, religie și controlul asupra "mirodeniei".' },
  { title: 'Fahrenheit 451', author: 'Ray Bradbury', isbn: '9781451673319', genre: 'Distopie', publishedYear: 1953, language: 'Română', pageCount: 256, description: 'Într-o societate care arde cărțile, pompierul Guy Montag începe să pună la îndoială rostul acestei meserii.' },
  { title: 'Minunata lume nouă', author: 'Aldous Huxley', isbn: '9780060850524', genre: 'Distopie', publishedYear: 1932, language: 'Română', pageCount: 311, description: 'O societate viitoare controlată prin plăcere, condiționare genetică și droguri, nu prin frică.' },
  { title: 'Codul lui Da Vinci', author: 'Dan Brown', isbn: '9780307474278', genre: 'Thriller', publishedYear: 2003, language: 'Română', pageCount: 489, description: 'O crimă la Luvru declanșează o vânătoare de coduri ascunse și secrete legate de istoria creștinismului.' },
  { title: 'Educated', author: 'Tara Westover', isbn: '9780399590504', genre: 'Biografie', publishedYear: 2018, language: 'Engleză', pageCount: 334, description: 'Memoriile unei femei crescute izolat, fără școală, care ajunge totuși la Cambridge printr-o educație autodidactă.' },
  { title: 'Pădurea Norvegiană', author: 'Haruki Murakami', isbn: '9780375704024', genre: 'Ficțiune', publishedYear: 1987, language: 'Română', pageCount: 296, description: 'Un student japonez rememorează iubirile și pierderile studenției, pe fondul melancolic al anilor 60.' },
  { title: 'Vânătorul de zmeie', author: 'Khaled Hosseini', isbn: '9781594631931', genre: 'Ficțiune', publishedYear: 2003, language: 'Română', pageCount: 371, description: 'Prietenia dintre doi băieți din Kabul, umbrită de o trădare, urmărită pe fundalul istoriei zbuciumate a Afganistanului.' },
  { title: 'Viața lui Pi', author: 'Yann Martel', isbn: '9780156027328', genre: 'Ficțiune', publishedYear: 2001, language: 'Română', pageCount: 319, description: 'Un băiat supraviețuiește 227 de zile pe ocean, într-o barcă de salvare împreună cu un tigru bengalez.' },
  { title: 'Strălucirea', author: 'Stephen King', isbn: '9780307743657', genre: 'Thriller', publishedYear: 1977, language: 'Română', pageCount: 447, description: 'O familie devine îngrijitoare de iarnă la un hotel izolat, ale cărui prezențe malefice îl posedă treptat pe tată.' },
  { title: 'Percy Jackson și Fulgerul Furat', author: 'Rick Riordan', isbn: '9780786838653', genre: 'Fantasy', publishedYear: 2005, language: 'Română', pageCount: 377, description: 'Un adolescent descoperă că e fiul lui Poseidon și pornește într-o căutare pentru a preveni un război între zei.' },
  { title: 'Divergent', author: 'Veronica Roth', isbn: '9780062024039', genre: 'SF', publishedYear: 2011, language: 'Română', pageCount: 487, description: 'Într-o societate împărțită pe facțiuni, Tris descoperă că nu se încadrează în niciuna și ascunde acest secret periculos.' },
  { title: 'Frankenstein', author: 'Mary Shelley', isbn: '9780486282114', genre: 'Clasic', publishedYear: 1818, language: 'Română', pageCount: 280, description: 'Savantul Victor Frankenstein dă viață unei creaturi pe care apoi o respinge, cu urmări tragice pentru amândoi.' },
  { title: 'Steve Jobs', author: 'Walter Isaacson', isbn: '9781451648539', genre: 'Biografie', publishedYear: 2011, language: 'Română', pageCount: 656, description: 'Biografia autorizată a cofondatorului Apple, de la garaj până la revoluționarea industriei tehnologice.' },
  { title: 'Winnie de Pluș', author: 'A.A. Milne', isbn: '9780525444435', genre: 'Copii', publishedYear: 1926, language: 'Română', pageCount: 176, description: 'Aventurile ursulețului Winnie și ale prietenilor săi din Pădurea de o Sută de Acri.' },
  { title: 'Charlie și Fabrica de Ciocolată', author: 'Roald Dahl', isbn: '9780142410318', genre: 'Copii', publishedYear: 1964, language: 'Română', pageCount: 176, description: 'Charlie Bucket câștigă un bilet de aur și vizitează fabrica de ciocolată a excentricului domn Willy Wonka.' },
  { title: 'Matilda', author: 'Roald Dahl', isbn: '9780142410370', genre: 'Copii', publishedYear: 1988, language: 'Română', pageCount: 240, description: 'O fetiță genială cu puteri telechinetice se confruntă cu părinți neglijenți și o directoare tiranică.' },
  { title: 'Război și pace', author: 'Lev Tolstoi', isbn: '9781400079988', genre: 'Clasic', publishedYear: 1869, language: 'Română', pageCount: 1225, description: 'Destinele mai multor familii aristocrate rusești, pe fondul invaziei napoleoniene din 1812.' },
  { title: 'Cel mai iubit dintre pământeni', author: 'Marin Preda', isbn: null, genre: 'Clasic românesc', publishedYear: 1980, language: 'Română', pageCount: 640, description: 'Victor Petrini povestește, din închisoare, un destin frânt de mecanismele represive ale regimului comunist.' },
  { title: 'Patul lui Procust', author: 'Camil Petrescu', isbn: null, genre: 'Clasic românesc', publishedYear: 1933, language: 'Română', pageCount: 280, description: 'Un roman construit din jurnale și scrisori încrucișate, despre iubiri și iluzii în Bucureștiul interbelic.' },
  { title: 'Ultima noapte de dragoste, întâia noapte de război', author: 'Camil Petrescu', isbn: null, genre: 'Clasic românesc', publishedYear: 1930, language: 'Română', pageCount: 320, description: 'Ștefan Gheorghidiu trece de la geloziile unei căsnicii la frontul Primului Război Mondial.' },
  { title: 'Groapa', author: 'Eugen Barbu', isbn: null, genre: 'Clasic românesc', publishedYear: 1957, language: 'Română', pageCount: 350, description: 'Lumea mahalalei bucureștene interbelice, cu personaje pestrițe adunate în cartierul „Groapa".' },
  { title: 'Nunta Domnitei Ruxanda', author: 'Bogdan Petriceicu Hasdeu', isbn: null, genre: 'Clasic românesc', publishedYear: 1877, language: 'Română', pageCount: 120, description: 'Dramă istorică despre intrigile de curte din jurul nunții fiicei lui Vasile Lupu.' },
  { title: 'Joc de-a vacanța', author: 'Mihail Sebastian', isbn: null, genre: 'Clasic românesc', publishedYear: 1938, language: 'Română', pageCount: 140, description: 'Piesă de teatru despre un grup de tineri care își petrec vacanța la munte, între iluzii și dezamăgiri.' },
  { title: 'It', author: 'Stephen King', isbn: '9781501142970', genre: 'Thriller', publishedYear: 1986, language: 'Română', pageCount: 1168, description: 'Un grup de copii din Derry se confruntă cu o entitate malefică ce revine la fiecare 27 de ani.' },
  { title: 'Cutremurul', author: 'Ken Follett', isbn: '9780451225467', genre: 'Thriller', publishedYear: 1978, language: 'Română', pageCount: 380, description: 'Un jurnalist descoperă un complot legat de securitatea unei centrale nucleare din Franța.' },
  { title: 'Circul de la miezul nopții', author: 'Erin Morgenstern', isbn: '9780385534635', genre: 'Fantasy', publishedYear: 2011, language: 'Română', pageCount: 512, description: 'Un circ misterios, deschis doar noaptea, devine scena unei competiții magice între doi tineri iluzioniști.' },
  { title: 'Numele Trandafirului', author: 'Umberto Eco', isbn: '9780156001311', genre: 'Clasic', publishedYear: 1980, language: 'Română', pageCount: 512, description: 'Un călugăr franciscan anchetează o serie de morți misterioase într-o mănăstire medievală italiană.' },
  { title: 'Cronica unei morți anunțate', author: 'Gabriel García Márquez', isbn: '9781400034716', genre: 'Ficțiune', publishedYear: 1981, language: 'Română', pageCount: 120, description: 'Toată lumea dintr-un orășel știe că Santiago Nasar va fi ucis - și totuși nimeni nu reușește să-l salveze.' },
  { title: 'O sută de ani de singurătate', author: 'Gabriel García Márquez', isbn: '9780060883287', genre: 'Ficțiune', publishedYear: 1967, language: 'Română', pageCount: 417, description: 'Șapte generații ale familiei Buendía, în orășelul fictiv Macondo, între realism și magie.' },
  { title: 'Talentatul domn Ripley', author: 'Patricia Highsmith', isbn: '9780393332144', genre: 'Thriller', publishedYear: 1955, language: 'Română', pageCount: 290, description: 'Tom Ripley e trimis în Italia să-l aducă acasă pe fiul unui magnat, dar ajunge să-i râvnească identitatea.' },
  { title: 'Educația unui om rațional', author: 'Ray Dalio', isbn: '9781501124020', genre: 'Dezvoltare personală', publishedYear: 2017, language: 'Engleză', pageCount: 592, description: 'Principii de viață și de management, distilate din cariera fondatorului unui fond de investiții.' },
  { title: 'Gândește repede, gândește încet', author: 'Daniel Kahneman', isbn: '9780374533557', genre: 'Non-ficțiune', publishedYear: 2011, language: 'Română', pageCount: 499, description: 'Un psiholog laureat Nobel explică cele două sisteme de gândire care ne modelează deciziile.' },
  { title: 'Puterea obiceiului', author: 'Charles Duhigg', isbn: '9780812981605', genre: 'Dezvoltare personală', publishedYear: 2012, language: 'Română', pageCount: 371, description: 'De ce se formează obiceiurile, cum funcționează în creier și cum pot fi schimbate deliberat.' },
];

const CONDITIONS: BookCondition[] = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'];

function coverUrlByIsbn(isbn: string): string {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;
}

/**
 * Cărțile clasice românești nu au ISBN modern unic (multe ediții diferite),
 * deci nu putem construi un URL de copertă direct din ISBN. Căutăm titlul pe
 * Open Library la seed-time, ca să nu rămână fără copertă - vezi bug-ul
 * raportat „Many books have no cover" (Milestone 19).
 */
async function findCoverByTitle(title: string, author: string): Promise<string | null> {
  try {
    const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(`${title} ${author}`)}&limit=1&fields=cover_i`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = (await res.json()) as { docs?: { cover_i?: number }[] };
    const coverId = data.docs?.[0]?.cover_i;
    return coverId ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : null;
  } catch (error) {
    console.warn(`Nu am găsit copertă pentru „${title}": ${error}`);
    return null;
  }
}

/**
 * Poze "puse de userul demo" pentru un anunț - URL-uri placeholder stabile
 * (același seed -> aceeași imagine la fiecare rulare). getPublicUrl le lasă
 * neschimbate fiindcă sunt deja absolute (vezi storage.service.ts).
 */
function demoPhotos(seedKey: string, count: number): string[] {
  return Array.from({ length: count }, (_, i) => `https://picsum.photos/seed/${seedKey}-${i}/600/800`);
}

async function main() {
  console.log('Curăț datele existente (doar tabelele demo, nu users creați manual cu alte email-uri)...');
  await prisma.notification.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.message.deleteMany({ where: { sender: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.conversation.deleteMany({
    where: {
      OR: [
        { userA: { email: { endsWith: '@shelfshare.demo' } } },
        { userB: { email: { endsWith: '@shelfshare.demo' } } },
      ],
    },
  });
  await prisma.wishlistItem.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.priceOffer.deleteMany({
    where: {
      OR: [
        { buyer: { email: { endsWith: '@shelfshare.demo' } } },
        { owner: { email: { endsWith: '@shelfshare.demo' } } },
      ],
    },
  });
  await prisma.exchangeRequest.deleteMany({
    where: {
      OR: [
        { requester: { email: { endsWith: '@shelfshare.demo' } } },
        { owner: { email: { endsWith: '@shelfshare.demo' } } },
      ],
    },
  });
  await prisma.userBook.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.book.deleteMany({ where: { source: 'demo-seed' } });
  await prisma.user.deleteMany({ where: { email: { endsWith: '@shelfshare.demo' } } });

  console.log('Creez utilizatori...');
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
  const users: User[] = [];
  for (let i = 0; i < USERS.length; i++) {
    const u = USERS[i];
    const emailSlug = u.name.toLowerCase().replace(/ș/g, 's').replace(/ț/g, 't').replace(/ă/g, 'a').replace(/â|î/g, 'i').replace(/\s+/g, '.');
    const user = await prisma.user.create({
      data: {
        email: `${emailSlug}@shelfshare.demo`,
        password: passwordHash,
        isEmailVerified: true,
        name: u.name,
        city: u.city,
        bio: u.bio,
        profileImage: `https://i.pravatar.cc/300?img=${(i % 70) + 1}`,
        rating: 0,
        booksExchangedCount: 0,
        createdAt: daysAgo(200 - i * 5),
      },
    });
    users.push(user);
  }

  console.log('Creez cărți...');
  const books: Book[] = [];
  for (const b of BOOKS) {
    const cover = b.isbn ? coverUrlByIsbn(b.isbn) : await findCoverByTitle(b.title, b.author);
    const book = await prisma.book.create({
      data: {
        isbn: b.isbn,
        title: b.title,
        author: b.author,
        genre: b.genre,
        publishedYear: b.publishedYear,
        language: b.language,
        pageCount: b.pageCount,
        coverUrl: cover ?? `https://picsum.photos/seed/${encodeURIComponent(b.title)}/400/600`,
        source: 'demo-seed',
        description: b.description,
      },
    });
    books.push(book);
  }

  console.log('Distribui cărțile în bibliotecile utilizatorilor...');
  const userBooks: UserBookWithMeta[] = [];
  for (let i = 0; i < books.length; i++) {
    const owner = pickSeeded(users, i * 3 + 1);
    const userBook = await prisma.userBook.create({
      data: {
        userId: owner.id,
        bookId: books[i].id,
        condition: pickSeeded(CONDITIONS, i),
        language: books[i].language,
        isHardcover: i % 3 === 0,
        availableForSwap: true,
        // Aplicația cere minim o poză reală per anunț - un seed fără poze ar
        // produce carduri goale peste tot în feed.
        photos: demoPhotos(`ub-${i}`, 1 + (i % 3)),
        viewCount: (i * 37) % 240,
        createdAt: daysAgo(180 - i * 4),
      },
    });
    userBooks.push({ ...userBook, ownerId: owner.id, bookTitle: books[i].title });
  }

  // Exemplare duplicate în alte biblioteci: creează suprapuneri (aceeași carte
  // la mai mulți useri) și ne duce la ~100 de anunțuri în total, împreună cu
  // re-listările generate mai jos.
  const TARGET_LISTINGS = 96; // + ~4 verigi de re-listare => ~100
  for (let i = 0; userBooks.length < TARGET_LISTINGS; i++) {
    const book = pickSeeded(books, i * 7 + 2);
    const owner = pickSeeded(users, i * 5 + 3);
    const userBook = await prisma.userBook.create({
      data: {
        userId: owner.id,
        bookId: book.id,
        condition: pickSeeded(CONDITIONS, i + 2),
        language: book.language,
        isHardcover: i % 4 === 0,
        availableForSwap: true,
        photos: demoPhotos(`dup-${i}`, 1 + (i % 2)),
        viewCount: (i * 53) % 180,
        createdAt: daysAgo(Math.max(1, 90 - i * 2)),
      },
    });
    userBooks.push({ ...userBook, ownerId: owner.id, bookTitle: book.title });
  }

  console.log('Marchez câteva cărți ca puse la vânzare, cu poze...');
  type ForSaleUserBook = UserBookWithMeta & { price: number };
  const forSaleIndices = [1, 4, 7, 10, 13, 16, 19, 22].filter((i) => i < userBooks.length);
  const forSaleUserBooks: ForSaleUserBook[] = [];
  for (const i of forSaleIndices) {
    const ub = userBooks[i];
    const price = 20 + (i % 8) * 15;
    const updated = await prisma.userBook.update({
      where: { id: ub.id },
      data: {
        isForSale: true,
        salePrice: price,
        isNegotiable: i % 3 !== 0,
        photos: demoPhotos(ub.id, 2),
      },
    });
    forSaleUserBooks.push({ ...updated, ownerId: ub.ownerId, bookTitle: ub.bookTitle, price });
  }

  console.log('Creez oferte de preț (istoric de oferte în diverse stări)...');
  type OfferPlan = { status: 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'CANCELLED'; daysBack: number };
  const offerPlans: OfferPlan[] = [
    { status: 'PENDING', daysBack: 2 },
    { status: 'PENDING', daysBack: 4 },
    { status: 'PENDING', daysBack: 1 },
    { status: 'ACCEPTED', daysBack: 10 },
    { status: 'REJECTED', daysBack: 15 },
    { status: 'CANCELLED', daysBack: 20 },
  ];
  for (let i = 0; i < offerPlans.length && i < forSaleUserBooks.length; i++) {
    const plan = offerPlans[i];
    const ub = forSaleUserBooks[i];
    let buyer = pickSeeded(users, i * 5 + 7);
    if (buyer.id === ub.ownerId) buyer = users[(users.indexOf(buyer) + 1) % users.length];

    await prisma.priceOffer.create({
      data: {
        buyerId: buyer.id,
        ownerId: ub.ownerId,
        userBookId: ub.id,
        amount: plan.status === 'ACCEPTED' ? Math.max(5, ub.price - 5) : ub.price,
        message: 'Salut! Aș fi interesat, accepți acest preț?',
        status: plan.status,
        createdAt: daysAgo(plan.daysBack + 1),
        updatedAt: daysAgo(plan.daysBack),
      },
    });

    if (plan.status === 'ACCEPTED') {
      await prisma.userBook.update({
        where: { id: ub.id },
        data: { isForSale: false, availableForSwap: false },
      });
    }
  }

  console.log(`Creez cererile de schimb (istoric complet)...`);
  const exchangeCount = new Map<string, number>();
  const bump = (userId: string) => exchangeCount.set(userId, (exchangeCount.get(userId) ?? 0) + 1);

  type Plan = { status: ExchangeStatus; daysBack: number };
  const plans: Plan[] = [
    ...Array(11).fill(null).map((_, i) => ({ status: 'COMPLETED' as ExchangeStatus, daysBack: 150 - i * 10 })),
    ...Array(4).fill(null).map((_, i) => ({ status: 'ACCEPTED' as ExchangeStatus, daysBack: 20 - i * 3 })),
    ...Array(6).fill(null).map((_, i) => ({ status: 'PENDING' as ExchangeStatus, daysBack: 6 - i })),
    ...Array(3).fill(null).map((_, i) => ({ status: 'REJECTED' as ExchangeStatus, daysBack: 45 - i * 8 })),
    ...Array(2).fill(null).map((_, i) => ({ status: 'CANCELLED' as ExchangeStatus, daysBack: 60 - i * 5 })),
  ];

  const conversationsMap = new Map<string, { id: string; a: string; b: string }>();
  const exchanges: ExchangeWithMeta[] = [];

  for (let i = 0; i < plans.length; i++) {
    const plan = plans[i];
    const requestedUB = pickSeeded(userBooks, i * 4 + 1);
    let requester = pickSeeded(users, i * 6 + 2);
    // solicitantul nu poate fi proprietarul cărții
    if (requester.id === requestedUB.ownerId) {
      requester = users[(users.indexOf(requester) + 1) % users.length];
    }

    const offerOwn = i % 3 !== 0;
    let offeredBookId: string | null = null;
    if (offerOwn) {
      const own = userBooks.filter((ub) => ub.ownerId === requester.id);
      if (own.length > 0) offeredBookId = pickSeeded(own, i).id;
    }

    const createdAt = daysAgo(plan.daysBack + 2);
    const updatedAt = daysAgo(plan.daysBack);

    const exchange = await prisma.exchangeRequest.create({
      data: {
        requesterId: requester.id,
        ownerId: requestedUB.ownerId,
        requestedBookId: requestedUB.id,
        offeredBookId,
        offeredAmount: offeredBookId ? null : 25 + (i % 5) * 10,
        status: plan.status,
        message: 'Salut! Aș fi interesat de această carte, ai vrea să facem un schimb?',
        createdAt,
        updatedAt,
      },
    });
    exchanges.push({ ...exchange, bookTitle: requestedUB.bookTitle });

    if (plan.status === 'COMPLETED') {
      bump(requester.id);
      bump(requestedUB.ownerId);
      await prisma.userBook.update({ where: { id: requestedUB.id }, data: { availableForSwap: false } });
      if (offeredBookId) await prisma.userBook.update({ where: { id: offeredBookId }, data: { availableForSwap: false } });
    } else if (plan.status === 'ACCEPTED') {
      await prisma.userBook.update({ where: { id: requestedUB.id }, data: { availableForSwap: false } });
      if (offeredBookId) await prisma.userBook.update({ where: { id: offeredBookId }, data: { availableForSwap: false } });
    }

    // conversație asociată schimbului (pentru cele acceptate/completate/pending avansate)
    if (plan.status !== 'CANCELLED') {
      const [userAId, userBId] = [requester.id, requestedUB.ownerId].sort();
      const key = `${userAId}:${userBId}`;
      if (!conversationsMap.has(key)) {
        const conv = await prisma.conversation.create({
          data: { userAId, userBId, createdAt, updatedAt },
        });
        conversationsMap.set(key, { id: conv.id, a: userAId, b: userBId });
      }
    }
  }

  console.log('Simulez re-listări (istoric traceable, cu poze pe fiecare verigă)...');
  const userBookById = new Map(userBooks.map((ub) => [ub.id, ub]));
  const completedExchanges = exchanges.filter((e) => e.status === 'COMPLETED').slice(0, 3);
  let firstRelistId: string | null = null;
  let firstRelistOwnerId: string | null = null;
  let firstRelistBookId: string | null = null;
  // Reținem lanțurile create ca să le putem raporta la final - altfel ar trebui
  // căutate manual în DB ca să vezi cum arată istoricul în aplicație.
  const provenance: { title: string; listingId: string; hops: number }[] = [];

  for (let i = 0; i < completedExchanges.length; i++) {
    const ex = completedExchanges[i];
    const original = userBookById.get(ex.requestedBookId);
    if (!original) continue;

    const relisted = await prisma.userBook.create({
      data: {
        userId: ex.requesterId,
        bookId: original.bookId,
        condition: pickSeeded(CONDITIONS, i + 1),
        photos: demoPhotos(`relist-${i}`, 2),
        availableForSwap: true,
        previousListingId: original.id,
        createdAt: new Date(ex.updatedAt.getTime() + 1000 * 60 * 60 * 24 * 3),
      },
    });

    provenance.push({ title: original.bookTitle, listingId: relisted.id, hops: 2 });

    if (i === 0) {
      firstRelistId = relisted.id;
      firstRelistOwnerId = relisted.userId;
      firstRelistBookId = relisted.bookId;
    }
  }

  // lanț de 3 verigi pentru cel puțin o carte, ca istoricul să arate mai mult decât un singur hop
  if (firstRelistId && firstRelistBookId) {
    const otherUser = users.find((u) => u.id !== firstRelistOwnerId) ?? users[0];
    const third = await prisma.userBook.create({
      data: {
        userId: otherUser.id,
        bookId: firstRelistBookId,
        condition: pickSeeded(CONDITIONS, 3),
        photos: demoPhotos('relist-chain-3', 1),
        availableForSwap: true,
        previousListingId: firstRelistId,
        createdAt: daysAgo(5),
      },
    });
    // Veriga a 3-a înlocuiește intrarea de 2 hop-uri a aceleiași cărți.
    const idx = provenance.findIndex((p) => p.listingId === firstRelistId);
    if (idx >= 0) provenance.splice(idx, 1);
    const title = books.find((b) => b.id === firstRelistBookId)?.title ?? '?';
    provenance.push({ title, listingId: third.id, hops: 3 });
  }

  console.log('Setez rating și contor de schimburi pe profiluri...');
  for (const user of users) {
    const count = exchangeCount.get(user.id) ?? 0;
    const rating = count === 0 ? 0 : Math.min(5, 3.4 + ((user.name ?? '').length % 7) * 0.23);
    await prisma.user.update({
      where: { id: user.id },
      data: { booksExchangedCount: count, rating: Math.round(rating * 10) / 10 },
    });
  }

  console.log('Adaug mesaje în conversații...');
  const sampleMessages = [
    'Salut! Am văzut cererea ta, cartea e încă disponibilă.',
    'Perfect, unde ne-am putea întâlni pentru schimb?',
    'Pot veni în centru, sâmbătă după-amiază?',
    'Sună bine, ne vedem atunci!',
    'Mulțumesc mult, cartea era exact ce căutam!',
    'Cu plăcere, spor la citit!',
    'Cartea e în stare foarte bună, are doar câteva însemnări pe margini.',
    'Nicio problemă, nu mă deranjează.',
    'Mai ai și alte cărți disponibile la schimb?',
    'Da, am actualizat biblioteca, mai uită-te.',
  ];
  let msgIdx = 0;
  for (const conv of conversationsMap.values()) {
    const msgCount = 2 + (msgIdx % 4);
    let lastCreated = daysAgo(30 - msgIdx);
    for (let m = 0; m < msgCount; m++) {
      const sender = m % 2 === 0 ? conv.a : conv.b;
      lastCreated = new Date(lastCreated.getTime() + 1000 * 60 * 60 * (m + 1));
      await prisma.message.create({
        data: {
          conversationId: conv.id,
          senderId: sender,
          content: pickSeeded(sampleMessages, msgIdx + m),
          isRead: m < msgCount - 1,
          createdAt: lastCreated,
        },
      });
    }
    await prisma.conversation.update({ where: { id: conv.id }, data: { updatedAt: lastCreated } });
    msgIdx++;
  }

  console.log('Adaug wishlist...');
  for (let i = 0; i < 14; i++) {
    const user = pickSeeded(users, i * 3 + 5);
    const book = pickSeeded(books, i * 5 + 1);
    await prisma.wishlistItem
      .create({ data: { userId: user.id, bookId: book.id, createdAt: daysAgo(40 - i) } })
      .catch(() => undefined); // ignora duplicate (constraint unique)
  }

  console.log('Adaug notificări...');
  for (const ex of exchanges) {
    if (ex.status === 'PENDING') {
      await prisma.notification.create({
        data: {
          userId: ex.ownerId,
          type: 'EXCHANGE_REQUEST_RECEIVED',
          message: `Ai primit o cerere de schimb pentru "${ex.bookTitle}"`,
          data: { exchangeRequestId: ex.id },
          isRead: false,
          createdAt: ex.createdAt,
        },
      });
    } else if (ex.status === 'ACCEPTED' || ex.status === 'COMPLETED') {
      await prisma.notification.create({
        data: {
          userId: ex.requesterId,
          type: 'EXCHANGE_REQUEST_ACCEPTED',
          message: `Cererea ta de schimb pentru "${ex.bookTitle}" a fost acceptată`,
          data: { exchangeRequestId: ex.id },
          isRead: true,
          createdAt: ex.updatedAt,
        },
      });
    } else if (ex.status === 'REJECTED') {
      await prisma.notification.create({
        data: {
          userId: ex.requesterId,
          type: 'EXCHANGE_REQUEST_REJECTED',
          message: `Cererea ta de schimb pentru "${ex.bookTitle}" a fost refuzată`,
          data: { exchangeRequestId: ex.id },
          isRead: true,
          createdAt: ex.updatedAt,
        },
      });
    }
  }
  for (const conv of conversationsMap.values()) {
    await prisma.notification.create({
      data: {
        userId: conv.a,
        type: 'NEW_MESSAGE',
        message: 'Ai un mesaj nou într-o conversație',
        data: { conversationId: conv.id },
        isRead: Math.random() > 0.5,
        createdAt: daysAgo(2),
      },
    });
  }

  console.log('Creez licitații (active + una încheiată), cu oferte și urmăritori...');
  // Alegem anunțuri care nu sunt deja la vânzare, ca un anunț să nu fie
  // simultan „de vânzare" și „la licitație".
  const auctionCandidates = userBooks.filter((ub) => !forSaleIndices.includes(userBooks.indexOf(ub)));
  const auctionPlans = [
    { endsInDays: 3, startPrice: 25, bids: 4, status: 'ACTIVE' as const },
    { endsInDays: 6, startPrice: 40, bids: 2, status: 'ACTIVE' as const },
    { endsInDays: 1, startPrice: 15, bids: 6, status: 'ACTIVE' as const },
    { endsInDays: -4, startPrice: 30, bids: 3, status: 'ENDED' as const },
  ];
  for (let i = 0; i < auctionPlans.length && i < auctionCandidates.length; i++) {
    const plan = auctionPlans[i];
    const ub = auctionCandidates[i * 5];
    if (!ub) continue;

    const currentPrice = plan.startPrice + plan.bids * 5;
    const endsAt = new Date(Date.now() + plan.endsInDays * 24 * 60 * 60 * 1000);

    const bidders = users.filter((u) => u.id !== ub.ownerId).slice(0, plan.bids);
    const topBidder = bidders[bidders.length - 1];

    await prisma.userBook.update({
      where: { id: ub.id },
      data: { isAuction: true, availableForSwap: false },
    });

    const auction = await prisma.auction.create({
      data: {
        userBookId: ub.id,
        startingPrice: plan.startPrice,
        buyNowPrice: i % 2 === 0 ? currentPrice + 40 : null,
        currentPrice,
        highestBidderId: topBidder?.id ?? null,
        endsAt,
        status: plan.status,
        createdAt: daysAgo(10),
      },
    });

    for (let b = 0; b < bidders.length; b++) {
      await prisma.bid.create({
        data: {
          auctionId: auction.id,
          bidderId: bidders[b].id,
          amount: plan.startPrice + (b + 1) * 5,
          createdAt: daysAgo(9 - b),
        },
      });
    }

    for (const watcher of users.filter((u) => u.id !== ub.ownerId).slice(0, 3)) {
      await prisma.auctionWatch.create({
        data: { auctionId: auction.id, userId: watcher.id },
      });
    }
  }

  console.log('Marchez utilizatori Premium și anunțuri promovate...');
  for (let i = 0; i < 3; i++) {
    await prisma.user.update({ where: { id: users[i].id }, data: { isPremium: true } });
  }
  // Anunțurile promovate apar primele în browse (vezi orderBy din searchLibrary).
  for (const ub of userBooks.filter((u) => users.slice(0, 3).some((p) => p.id === u.ownerId)).slice(0, 4)) {
    await prisma.userBook.update({ where: { id: ub.id }, data: { isPromoted: true } });
  }

  console.log('Creez colecții...');
  const collectionPlans = [
    { name: 'Clasici românești', description: 'Ce vreau să recitesc din literatura română.' },
    { name: 'SF & Distopii', description: 'Lista mea de SF, în ordinea în care le citesc.' },
    { name: 'De citit în vacanță', description: null },
  ];
  for (let i = 0; i < collectionPlans.length; i++) {
    const collection = await prisma.collection.create({
      data: {
        userId: users[i].id,
        name: collectionPlans[i].name,
        description: collectionPlans[i].description,
        isPublic: true,
        createdAt: daysAgo(40 - i * 5),
      },
    });
    const chosen = new Set<string>();
    for (let j = 0; j < 6; j++) {
      const book = pickSeeded(books, i * 11 + j * 3);
      if (chosen.has(book.id)) continue;
      chosen.add(book.id);
      await prisma.collectionItem.create({
        data: { collectionId: collection.id, bookId: book.id },
      });
    }
  }

  console.log('Creez grupuri cu membri și discuții...');
  const groupPlans = [
    { name: 'Cititori din București', description: 'Ne întâlnim lunar și facem schimburi în persoană.' },
    { name: 'Fan Fantasy România', description: 'Tolkien, Sanderson, Martin - discuții și schimburi.' },
    { name: 'Clubul de lectură Cluj', description: 'O carte pe lună, discuție la final.' },
  ];
  for (let i = 0; i < groupPlans.length; i++) {
    const creator = users[i + 2];
    const group = await prisma.group.create({
      data: {
        name: groupPlans[i].name,
        description: groupPlans[i].description,
        creatorId: creator.id,
        isPublic: true,
        createdAt: daysAgo(70 - i * 10),
      },
    });

    await prisma.groupMember.create({
      data: { groupId: group.id, userId: creator.id, role: 'ADMIN', joinedAt: daysAgo(70 - i * 10) },
    });
    for (const member of users.filter((u) => u.id !== creator.id).slice(0, 5 + i)) {
      await prisma.groupMember.create({
        data: { groupId: group.id, userId: member.id, role: 'MEMBER', joinedAt: daysAgo(60 - i * 8) },
      });
    }

    const posts = [
      'Salut tuturor! Ce citiți luna asta?',
      'Am terminat cartea propusă, mi-a plăcut mult finalul.',
      'Cine vine la întâlnirea de sâmbătă?',
    ];
    for (let p = 0; p < posts.length; p++) {
      await prisma.groupPost.create({
        data: {
          groupId: group.id,
          authorId: pickSeeded(users, i * 4 + p).id,
          content: posts[p],
          createdAt: daysAgo(20 - p * 5),
        },
      });
    }
  }

  console.log('Populez rafturile personale (citite / în curs / de citit)...');
  const shelfStatuses = ['FINISHED', 'READING', 'WANT_TO_READ'] as const;
  for (let i = 0; i < users.length; i++) {
    const used = new Set<string>();
    for (let j = 0; j < 8; j++) {
      const book = pickSeeded(books, i * 7 + j * 5);
      if (used.has(book.id)) continue;
      used.add(book.id);
      await prisma.bookshelfEntry.create({
        data: {
          userId: users[i].id,
          bookId: book.id,
          status: shelfStatuses[j % shelfStatuses.length],
          createdAt: daysAgo(120 - j * 10),
        },
      });
    }
  }

  console.log('Creez relații de urmărire între utilizatori...');
  for (let i = 0; i < users.length; i++) {
    for (let j = 1; j <= 3; j++) {
      const target = users[(i + j * 2) % users.length];
      if (target.id === users[i].id) continue;
      await prisma.follow.create({
        data: { followerId: users[i].id, followingId: target.id, createdAt: daysAgo(50 - j * 5) },
      }).catch(() => undefined); // unique(follower, following) - ignorăm coliziunile
    }
  }

  const totalListings = await prisma.userBook.count();

  console.log('\n=====================================================');
  console.log(`Gata! ${totalListings} anunțuri în total.`);
  console.log('=====================================================');
  console.log('\nCărțile CU ISTORIC (lanț de proprietari) - deschide-le ca să vezi secțiunea "Istoricul cărții":\n');
  for (const p of provenance) {
    console.log(`  • ${p.title}  (${p.hops} proprietari)`);
    console.log(`    /books/${p.listingId}`);
  }
  console.log('\nLogin de test: oricare email de mai jos + parola "Parola123!"');
  console.log(users.slice(0, 5).map((u) => '  ' + u.email).join('\n'));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
