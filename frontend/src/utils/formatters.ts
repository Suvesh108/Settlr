export function formatMoney(paise: number, currency: string = 'INR'): string {
  const isNegative = paise < 0;
  const absPaise = Math.abs(paise);
  const units = (absPaise / 100).toFixed(2);

  const symbol = currency === 'INR' ? '₹' : currency === 'USD' ? '$' : currency === 'EUR' ? '€' : `${currency} `;
  return `${isNegative ? '-' : ''}${symbol}${Number(units).toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function formatDate(isoStr: string): string {
  try {
    const d = new Date(isoStr);
    return d.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return isoStr;
  }
}
