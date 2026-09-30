import { isAllowedImageUrl } from './image-url';

describe('isAllowedImageUrl', () => {
  const storage = 'https://storage.shelfshare.ro/shelfshare';

  it('accepta pozele din stocarea noastra si copertele din sursele cunoscute', () => {
    expect(isAllowedImageUrl(`${storage}/user-books/a.webp`, storage)).toBe(true);
    expect(isAllowedImageUrl('https://covers.openlibrary.org/b/isbn/1-L.jpg', storage)).toBe(true);
    // Google Books intoarce des coperti pe http.
    expect(
      isAllowedImageUrl('http://books.google.com/books/content?id=x&img=1', storage),
    ).toBe(true);
    expect(isAllowedImageUrl('https://www.targulcartii.ro/img/x.jpg', storage)).toBe(true);
  });

  it('accepta stocarea de test de pe localhost', () => {
    const test = 'http://localhost:59000/shelfshare';
    expect(isAllowedImageUrl(`${test}/user-books/a.webp`, test)).toBe(true);
  });

  it('respinge orice alta gazda (pixel de urmarire)', () => {
    expect(isAllowedImageUrl('https://evil.test/pixel.gif', storage)).toBe(false);
    expect(isAllowedImageUrl('https://books.google.com.evil.test/x', storage)).toBe(false);
    expect(isAllowedImageUrl('https://books.google.com@evil.test/x', storage)).toBe(false);
    // Alt bucket de pe aceeasi gazda de stocare.
    expect(
      isAllowedImageUrl('https://storage.shelfshare.ro/altceva/x.webp', storage),
    ).toBe(false);
    expect(isAllowedImageUrl(`${storage}evil/x.webp`, storage)).toBe(false);
  });

  it('respinge ce nu e URL http(s)', () => {
    expect(isAllowedImageUrl('javascript:alert(1)', storage)).toBe(false);
    expect(isAllowedImageUrl('data:image/svg+xml,<svg/>', storage)).toBe(false);
    expect(isAllowedImageUrl('user-books/a.webp', storage)).toBe(false);
  });
});
