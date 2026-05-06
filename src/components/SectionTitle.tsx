export function SectionTitle({
  eyebrow,
  title,
  subtitle,
  align = "center",
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  align?: "center" | "left";
}) {
  return (
    <div className={align === "center" ? "text-center max-w-2xl mx-auto" : "max-w-2xl"}>
      {eyebrow && <span className="divider-zz mb-5">{eyebrow}</span>}
      <h2 className="font-serif text-4xl md:text-5xl text-foreground leading-tight">
        {title}
      </h2>
      {subtitle && (
        <p className="mt-5 text-muted-foreground leading-relaxed">{subtitle}</p>
      )}
    </div>
  );
}
