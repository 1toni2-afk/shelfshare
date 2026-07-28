import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor() {
    // `keepAlive` activează SO_KEEPALIVE la nivel de socket - OS-ul trimite
    // pachete goale periodic, ceea ce menține conexiunea prin router/firewall
    // și detectează rapid conexiunile moarte.
    //
    // `idleTimeoutMillis: 0` spune pool-ului să NU închidă conexiunile idle;
    // altfel, default-ul de 10s ducea la un cold start de câteva secunde per
    // conexiune (TCP + SSL + auth) la primul request după o pauză - vizibil
    // acut pe ecranul Discover, unde se fac ~10 request-uri simultan.
    const adapter = new PrismaPg({
      connectionString: process.env.DATABASE_URL,
      keepAlive: true,
      idleTimeoutMillis: 0,
    });
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
