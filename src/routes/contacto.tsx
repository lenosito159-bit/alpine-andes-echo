import { createFileRoute } from "@tanstack/react-router";
import { SectionTitle } from "@/components/SectionTitle";
import { MapPin, Phone, Mail, Clock, Instagram, Facebook } from "lucide-react";

export const Route = createFileRoute("/contacto")({
  head: () => ({
    meta: [
      { title: "Contacto y Ubicación — ZigZag Restaurant Arequipa" },
      { name: "description", content: "Calle Zela 210-212, Centro Histórico de Arequipa. Teléfono, horarios y mapa de ZigZag Restaurant." },
      { property: "og:title", content: "Contacto — ZigZag Restaurant" },
      { property: "og:description", content: "Encuéntranos en el corazón del Centro Histórico de Arequipa." },
    ],
  }),
  component: ContactoPage,
});

function ContactoPage() {
  return (
    <div>
      <section className="py-20 text-center px-6">
        <SectionTitle eyebrow="Contacto" title="Encuéntranos" subtitle="En el corazón del Centro Histórico de Arequipa, a una cuadra de la Plaza de Armas." />
      </section>

      <section className="mx-auto max-w-7xl px-6 pb-20 grid md:grid-cols-2 gap-12">
        <div className="space-y-8">
          <Item icon={<MapPin />} title="Dirección" lines={["Calle Zela 210-212", "Centro Histórico, Arequipa, Perú"]} />
          <Item icon={<Phone />} title="Teléfono" lines={["+51 54 206020"]} />
          <Item icon={<Mail />} title="Email" lines={["reservas@zigzagrestaurant.com"]} />
          <Item
            icon={<Clock />}
            title="Horario"
            lines={["Lunes a Domingo", "12:00 — 23:00"]}
          />
          <div>
            <h3 className="font-serif text-lg text-primary mb-3">Síguenos</h3>
            <div className="flex gap-4">
              <a href="#" aria-label="Instagram" className="border border-border p-3 hover:bg-primary hover:text-primary-foreground transition-colors"><Instagram size={18} /></a>
              <a href="#" aria-label="Facebook" className="border border-border p-3 hover:bg-primary hover:text-primary-foreground transition-colors"><Facebook size={18} /></a>
            </div>
          </div>
        </div>

        <div className="h-[520px] border border-border overflow-hidden">
          <iframe
            title="Ubicación ZigZag Restaurant"
            src="https://www.google.com/maps?q=Calle+Zela+210,+Arequipa,+Peru&output=embed"
            className="w-full h-full"
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
          />
        </div>
      </section>
    </div>
  );
}

function Item({ icon, title, lines }: { icon: React.ReactNode; title: string; lines: string[] }) {
  return (
    <div className="flex gap-5">
      <div className="text-primary mt-1">{icon}</div>
      <div>
        <h3 className="font-serif text-xl">{title}</h3>
        {lines.map((l) => <p key={l} className="text-muted-foreground">{l}</p>)}
      </div>
    </div>
  );
}
