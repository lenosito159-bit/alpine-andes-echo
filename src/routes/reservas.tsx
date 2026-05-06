import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { SectionTitle } from "@/components/SectionTitle";
import { Calendar, Clock, Users, Check } from "lucide-react";

export const Route = createFileRoute("/reservas")({
  head: () => ({
    meta: [
      { title: "Reservas — ZigZag Restaurant Arequipa" },
      { name: "description", content: "Reserva tu mesa en ZigZag Restaurant. Centro Histórico de Arequipa." },
      { property: "og:title", content: "Reservas — ZigZag Restaurant" },
      { property: "og:description", content: "Asegura tu lugar en una de las experiencias gastronómicas más queridas de Arequipa." },
    ],
  }),
  component: ReservasPage,
});

function ReservasPage() {
  const [sent, setSent] = useState(false);
  return (
    <div className="bg-card">
      <section className="bg-primary text-primary-foreground py-20 text-center px-6">
        <span className="divider-zz text-gold mb-4">Reservas</span>
        <h1 className="font-serif text-5xl md:text-6xl">Reserva tu mesa</h1>
        <p className="mt-4 max-w-xl mx-auto text-primary-foreground/85">
          Recomendamos reservar con anticipación, especialmente fines de semana y temporada alta.
        </p>
      </section>

      <section className="mx-auto max-w-3xl px-6 py-20">
        {sent ? (
          <div className="text-center py-20 border border-border bg-background">
            <Check className="mx-auto text-primary mb-4" size={48} />
            <h2 className="font-serif text-3xl">¡Solicitud recibida!</h2>
            <p className="mt-3 text-muted-foreground">Te confirmaremos tu reserva por correo en menos de 2 horas.</p>
          </div>
        ) : (
          <form
            onSubmit={(e) => { e.preventDefault(); setSent(true); }}
            className="bg-background p-8 md:p-12 border border-border space-y-6"
          >
            <SectionTitle title="Detalles de tu reserva" align="left" />
            <div className="grid md:grid-cols-2 gap-5 mt-6">
              <Field label="Nombre completo" name="nombre" required />
              <Field label="Teléfono" name="telefono" type="tel" required />
              <Field label="Email" name="email" type="email" required className="md:col-span-2" />
              <Field label="Fecha" name="fecha" type="date" icon={<Calendar size={16} />} required />
              <Field label="Hora" name="hora" type="time" icon={<Clock size={16} />} required />
              <Field label="Comensales" name="personas" type="number" min={1} max={20} defaultValue={2} icon={<Users size={16} />} required className="md:col-span-2" />
              <div className="md:col-span-2">
                <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-2">Notas adicionales</label>
                <textarea name="notas" rows={4} className="w-full border border-input bg-background px-4 py-3 focus:outline-none focus:border-primary" placeholder="Alergias, ocasión especial, preferencias..." />
              </div>
            </div>
            <button type="submit" className="w-full bg-primary text-primary-foreground py-4 text-xs uppercase tracking-[0.25em] hover:bg-accent transition-colors">
              Solicitar reserva
            </button>
          </form>
        )}
      </section>
    </div>
  );
}

function Field({ label, icon, className, ...props }: { label: string; icon?: React.ReactNode; className?: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className={className}>
      <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-2">{label}</label>
      <div className="relative">
        {icon && <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground">{icon}</span>}
        <input
          {...props}
          className={`w-full border border-input bg-background px-4 py-3 focus:outline-none focus:border-primary ${icon ? "pl-10" : ""}`}
        />
      </div>
    </div>
  );
}
