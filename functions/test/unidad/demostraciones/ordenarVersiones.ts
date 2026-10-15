/** Demostración 1: ordena versiones de la más vieja a la más nueva. */
export function ordenarVersiones(versiones: string[]): string[] {
  // Por número, tramo a tramo: como texto, «1.5.10» va antes que «1.5.9».
  const tramos = (v: string): number[] => v.split('.').map(Number);
  return [...versiones].sort((a, b) => {
    const x = tramos(a);
    const y = tramos(b);
    for (let i = 0; i < 3; i += 1) {
      if (x[i] !== y[i]) {
        return (x[i] ?? 0) - (y[i] ?? 0);
      }
    }
    return 0;
  });
}
