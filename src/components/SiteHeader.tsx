import { Link } from "@tanstack/react-router";
import { useState } from "react";
import logo from "@/assets/zigzag-logo.png";
import { Menu, X } from "lucide-react";

const links = [
  { to: "/", label: "Inicio" },
  { to: "/menu", label: "Menú" },
  { to: "/historia", label: "Nuestra Historia" },
  { to: "/galeria", label: "Galería" },
  { to: "/reservas", label: "Reservas" },
  { to: "/contacto", label: "Contacto" },
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="sticky top-0 z-40 w-full border-b border-border/60 bg-background/85 backdrop-blur-md">
      <div className="mx-auto flex h-20 max-w-7xl items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-3" onClick={() => setOpen(false)}>
          <img src={logo} alt="ZigZag Restaurant" className="h-12 w-12 object-contain" />
          <div className="hidden sm:block leading-tight">
            <div className="font-serif text-xl text-primary">ZigZag</div>
            <div className="text-[10px] tracking-[0.3em] uppercase text-muted-foreground">Restaurant · Arequipa</div>
          </div>
        </Link>
        <nav className="hidden lg:flex items-center gap-8">
          {links.map((l) => (
            <Link
              key={l.to}
              to={l.to}
              className="text-sm tracking-wide text-foreground/80 hover:text-primary transition-colors"
              activeProps={{ className: "text-primary font-medium" }}
              activeOptions={{ exact: l.to === "/" }}
            >
              {l.label}
            </Link>
          ))}
          <Link
            to="/reservas"
            className="rounded-sm border border-primary px-5 py-2 text-xs uppercase tracking-[0.2em] text-primary hover:bg-primary hover:text-primary-foreground transition-colors"
          >
            Reservar
          </Link>
        </nav>
        <button
          className="lg:hidden text-foreground"
          onClick={() => setOpen(!open)}
          aria-label="Menu"
        >
          {open ? <X /> : <Menu />}
        </button>
      </div>
      {open && (
        <nav className="lg:hidden border-t border-border/60 bg-background px-6 py-4 flex flex-col gap-3">
          {links.map((l) => (
            <Link
              key={l.to}
              to={l.to}
              onClick={() => setOpen(false)}
              className="py-2 text-foreground/80 hover:text-primary"
              activeProps={{ className: "text-primary font-medium" }}
              activeOptions={{ exact: l.to === "/" }}
            >
              {l.label}
            </Link>
          ))}
        </nav>
      )}
    </header>
  );
}
