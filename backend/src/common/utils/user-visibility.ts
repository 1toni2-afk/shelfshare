/** Numele real e ascuns dacă userul a dezactivat vizibilitatea publică - username-ul rămâne mereu vizibil. */
export function publicName(user: {
  name: string | null;
  nameVisible: boolean;
}): string | null {
  return user.nameVisible ? user.name : null;
}
