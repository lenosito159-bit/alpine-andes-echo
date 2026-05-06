import { createFileRoute } from "@tanstack/react-router";
import landscape from "@/assets/landscape.jpg";
import interior from "@/assets/interior.jpg";
import { SectionTitle } from "@/components/SectionTitle";

export const Route = createFileRoute("/historia")({
  head: () => ({
    meta: [
      { title: "Nuestra Historia — ZigZag Restaurant" },
      { name: "description", content: "La historia de ZigZag: una fusión nacida del encuentro entre los Alpes y los Andes en una bóveda de sillar de Arequipa." },
      { property: "og:title", content: "Nuestra Historia — ZigZag Restaurant" },
      { property: "og:description", content: "Dos cordilleras, una pasión gastronómica." },
      { property: "og:image", content: landscape },
    ],
  }),
  component: HistoryPage,
});

function HistoryPage() {
  return (
    <div>
      <section className="relative h-[60vh] min-h-[420px] overflow-hidden">
        <img src={landscape} alt="Cordilleras" className="absolute inset-0 w-full h-full object-cover" />
        <div className="absolute inset-0 bg-black/50" />
        <div className="relative z-10 h-full flex flex-col items-center justify-center text-center text-primary-foreground px-6">
          <span className="divider-zz text-gold mb-4">Nuestra Historia</span>
          <h1 className="font-serif text-5xl md:text-7xl">Entre dos cordilleras</h1>
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-6 py-20 prose-lg">
        <SectionTitle title="Una pasión nacida en la montaña" align="left" />
        <div className="mt-8 space-y-6 text-foreground/85 leading-relaxed">
          <p>
            ZigZag Restaurant abrió sus puertas en una bóveda colonial de sillar del siglo XVI, en el corazón del Centro Histórico de Arequipa. Lo que comenzó como un sueño compartido entre dos culturas, se convirtió en una de las experiencias gastronómicas más reconocidas del sur del Perú.
          </p>
          <p>
            Inspirados por los Alpes suizos y los Andes peruanos, decidimos que ambas tradiciones merecían dialogar en el mismo plato. La precisión técnica europea encontró su complemento perfecto en la abundancia y carácter de los ingredientes andinos.
          </p>
          <p>
            Trabajamos directamente con pequeños productores de la región: pastores de altura, queseros artesanales, agricultores de quinua y papas nativas. Cada ingrediente tiene origen, nombre y una historia que contamos a través de nuestra cocina.
          </p>
        </div>
      </section>

      <section className="bg-card py-20">
        <div className="mx-auto max-w-6xl px-6 grid md:grid-cols-2 gap-12 items-center">
          <img src={interior} alt="Interior" className="w-full h-[480px] object-cover" loading="lazy" />
          <div>
            <SectionTitle eyebrow="Filosofía" title="Honestidad, técnica y memoria" align="left" />
            <ul className="mt-8 space-y-5">
              {[
                ["Producto local", "Cada ingrediente proviene de productores que conocemos por su nombre."],
                ["Técnica honesta", "Cocciones precisas, sin artificios. La técnica al servicio del sabor."],
                ["Hospitalidad arequipeña", "El servicio como una extensión natural de la mesa."],
                ["Memoria viva", "Recuperamos recetas y técnicas que estaban a punto de perderse."],
              ].map(([t, d]) => (
                <li key={t} className="border-l-2 border-primary pl-5">
                  <h3 className="font-serif text-lg text-primary">{t}</h3>
                  <p className="text-sm text-muted-foreground mt-1">{d}</p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>
    </div>
  );
}
