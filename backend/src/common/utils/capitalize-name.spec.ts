import { capitalizeName } from './capitalize-name';

describe('capitalizeName', () => {
  it('pune majusculă la fiecare cuvânt dintr-un nume scris cu litere mici', () => {
    expect(capitalizeName('ion popescu')).toBe('Ion Popescu');
  });

  it('tratează numele compuse cu cratimă', () => {
    expect(capitalizeName('ana-maria ionescu')).toBe('Ana-Maria Ionescu');
  });

  it('tratează apostroful', () => {
    expect(capitalizeName("sean o'neil")).toBe("Sean O'Neil");
  });

  it('nu strică formele scrise intenționat cu majuscule interioare', () => {
    expect(capitalizeName('Ronald McDonald')).toBe('Ronald McDonald');
  });

  it('curăță spațiile de la capete și pe cele duplicate', () => {
    expect(capitalizeName('  ion   popescu  ')).toBe('Ion Popescu');
  });

  it('păstrează diacriticele', () => {
    expect(capitalizeName('ștefan țăndărică')).toBe('Ștefan Țăndărică');
  });
});
