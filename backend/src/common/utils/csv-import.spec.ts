import { cleanImportIsbn, cleanImportText } from './csv-import';

describe('cleanImportIsbn', () => {
  it('accepta ISBN-10 si ISBN-13 cu cifra de control corecta', () => {
    expect(cleanImportIsbn('0143039954')).toBe('0143039954');
    expect(cleanImportIsbn('978-0-441-01359-3')).toBe('9780441013593');
    expect(cleanImportIsbn('080442957x')).toBe('080442957X');
  });

  it('scoate invelisul Excel al exportului Goodreads', () => {
    expect(cleanImportIsbn('="0143039954"')).toBe('0143039954');
    expect(cleanImportIsbn('=""')).toBeUndefined();
  });

  it('respinge cifre de control gresite si orice nu e ISBN', () => {
    expect(cleanImportIsbn('1234567890')).toBeUndefined();
    expect(cleanImportIsbn('9780441013590')).toBeUndefined();
    expect(cleanImportIsbn('12345678901')).toBeUndefined();
    expect(cleanImportIsbn('=HYPERLINK("https://evil.test")')).toBeUndefined();
    expect(cleanImportIsbn('X123456789')).toBeUndefined();
  });
});

describe('cleanImportText', () => {
  it('taie la plafon si intoarce null pentru valori goale', () => {
    expect(cleanImportText('a'.repeat(400), 300)).toHaveLength(300);
    expect(cleanImportText('   ', 300)).toBeNull();
    expect(cleanImportText(null, 300)).toBeNull();
  });

  it('scoate caracterele de control si suprascrierile de directie', () => {
    expect(cleanImportText('Du\u0000ne‮', 300)).toBe('Dune');
    expect(cleanImportText('Dune\r\nATTENDEE:x', 300)).toBe('Dune ATTENDEE:x');
  });

  it('pastreaza liniile doar unde sunt cerute', () => {
    expect(
      cleanImportText('rand 1\r\n\r\n\r\n\r\nrand 2', 256, { multiline: true }),
    ).toBe('rand 1\n\nrand 2');
  });

  it('scoate apostroful pus de export in fata unei formule', () => {
    expect(cleanImportText("'=1+1", 300)).toBe('=1+1');
    expect(cleanImportText("'-30-", 300)).toBe('-30-');
    expect(cleanImportText("L'Étranger", 300)).toBe("L'Étranger");
  });
});
