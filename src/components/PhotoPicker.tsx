import { useRef } from 'react';

/** زرار عربي لاختيار الصور (بدل زرار المتصفح اللي بيظهر بالإنجليزي). على الموبايل بيفتح الكاميرا. */
export function PhotoPicker({
  onPick,
  disabled,
  label = '📷 إضافة صور',
}: {
  onPick: (files: File[]) => void;
  disabled?: boolean;
  label?: string;
}) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <button type="button" disabled={disabled} onClick={() => ref.current?.click()}>
        {label}
      </button>
      <input
        ref={ref}
        type="file"
        accept="image/*"
        multiple
        capture="environment"
        hidden
        onChange={(e) => {
          onPick(Array.from(e.target.files ?? []));
          e.target.value = '';
        }}
      />
    </>
  );
}
