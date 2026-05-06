import { Link } from "@tanstack/react-router";
import { Instagram, Facebook, MapPin, Phone, Mail } from "lucide-react";

export function SiteFooter() {
  return (
    <footer className="bg-secondary text-secondary-foreground mt-24">
      <div className="mx-auto max-w-7xl px-6 py-16 grid gap-12 md:grid-cols-4">
        <div className="md:col-span-2">
          <h3 className="font-serif text-3xl">ZigZag Restaurant</h3>
          <p className="mt-3 max-w-md text-sm text-secondary-foreground/75 leading-relaxed">
            Una travesía culinaria entre los Alpes y los Andes, en el corazón histórico de Arequipa desde hace más de dos décadas.
          </p>
          <div className="mt-6 flex gap-4">
            <a href="#" aria-label="Instagram" className="hover:text-gold transition-colors"><Instagram size={20} /></a>
            <a href="#" aria-label="Facebook" className="hover:text-gold transition-colors"><Facebook size={20} /></a>
          </div>
        </div>
        <div>
          <h4 className="font-serif text-lg mb-4">Visítanos</h4>
          <ul className="space-y-3 text-sm text-secondary-foreground/80">
            <li className="flex gap-2"><MapPin size={16} className="mt-0.5 shrink-0" /> Calle Zela 210-212, Centro Histórico, Arequipa</li>
            <li className="flex gap-2"><Phone size={16} className="mt-0.5 shrink-0" /> +51 54 206020</li>
            <li className="flex gap-2"><Mail size={16} className="mt-0.5 shrink-0" /> reservas@zigzagrestaurant.com</li>
          </ul>
        </div>
        <div>
          <h4 className="font-serif text-lg mb-4">Explorar</h4>
          <ul className="space-y-2 text-sm text-secondary-foreground/80">
            <li><Link to="/menu" className="hover:text-gold">Menú</Link></li>
            <li><Link to="/historia" className="hover:text-gold">Nuestra Historia</Link></li>
            <li><Link to="/galeria" className="hover:text-gold">Galería</Link></li>
            <li><Link to="/reservas" className="hover:text-gold">Reservas</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-secondary-foreground/15 py-6 text-center text-xs tracking-wider text-secondary-foreground/60">
        © {new Date().getFullYear()} ZigZag Restaurant · Arequipa, Perú
      </div>
    </footer>
  );
}
