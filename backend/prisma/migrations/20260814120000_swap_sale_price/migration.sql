-- „Sau vinde cu X lei" pe anunțurile de tip Schimb: un preț opțional setat la
-- listare, care permite oferte în bani fără ca anunțul să devină „Vânzare"
-- (isForSale rămâne false, deci categoria rămâne Schimb în bibliotecă/browse).
ALTER TABLE "user_books" ADD COLUMN "swapSalePrice" DECIMAL(10,2);
