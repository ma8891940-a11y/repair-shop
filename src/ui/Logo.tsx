/** علامة البرنامج: دايرة معايرة بأربع علامات قياس ونقطة إبراز في النص (تصميم أصلي) */
export function Mark({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden>
      <rect x="0.5" y="0.5" width="31" height="31" rx="7.5" fill="var(--raised)" stroke="var(--line-strong)" />
      <circle cx="16" cy="16" r="8" fill="none" stroke="var(--text)" strokeWidth="1.6" />
      <g stroke="var(--text)" strokeWidth="1.6" strokeLinecap="round">
        <path d="M16 5.5v3" />
        <path d="M16 23.5v3" />
        <path d="M5.5 16h3" />
        <path d="M23.5 16h3" />
      </g>
      <circle cx="16" cy="16" r="2.4" fill="var(--accent)" />
    </svg>
  );
}
