import { createFileRoute, Link } from "@tanstack/react-router";
import heroDish from "@/assets/hero-dish.jpg";
import interior from "@/assets/interior.jpg";
import landscape from "@/assets/landscape.jpg";
import dishSteak from "@/assets/dish-steak.jpg";
import dishFondue from "@/assets/dish-fondue.jpg";
import dishCeviche from "@/assets/dish-ceviche.jpg";
import { SectionTitle } from "@/components/SectionTitle";
import { Award, Leaf, Mountain, Star } from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "ZigZag Restaurant — Cocina Alpina y Andina · Arequipa" },
      { name: "description", content: "Restaurante de fusión alpina y andina en el Centro Histórico de Arequipa. Steakhouse, ingredientes naturales y experiencias inolvidables." },
      { property: "og:title", content: "ZigZag Restaurant — Arequipa" },
      { property: "og:description", content: "Cocina alpina y andina en una bóveda de sillar del siglo XVI." },
      { property: "og:image", content: heroDish },
    ],
  }),
  component: Home,
});

function Home() {
  return (
    <>
      {/* HERO */}
      <section className="relative h-[92vh] min-h-[640px] w-full overflow-hidden">
        <img
          src={heroDish}
          alt="Plato firma de ZigZag Restaurant"
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-black/30 to-black/80" />
        <div className="relative z-10 flex h-full flex-col items-center justify-center text-center px-6 text-primary-foreground">
          <span className="divider-zz text-gold mb-6">Arequipa · Desde 1999</span>
          <h1 className="font-serif text-5xl md:text-7xl lg:text-8xl max-w-5xl leading-[1.05]">
            Donde los <span className="font-display text-gold">Alpes</span> abrazan los <span className="font-display text-gold">Andes</span>
          </h1>
          <p className="mt-6 max-w-xl text-lg text-primary-foreground/85">
            Una cocina de autor que celebra la unión de dos culturas montañosas, servida bajo bóvedas de sillar del siglo XVI.
          </p>
          <div className="mt-10 flex flex-wrap gap-4 justify-center">
            <Link
              to="/reservas"
              className="bg-primary text-primary-foreground px-8 py-3.5 text-xs uppercase tracking-[0.25em] hover:bg-accent transition-colors"
            >
              Reservar mesa
            </Link>
            <Link
              to="/menu"
              className="border border-primary-foreground/70 text-primary-foreground px-8 py-3.5 text-xs uppercase tracking-[0.25em] hover:bg-primary-foreground hover:text-foreground transition-colors"
            >
              Ver menú
            </Link>
          </div>
        </div>
      </section>

      {/* AWARDS */}
      <section className="border-y border-border bg-card">
        <div className="mx-auto max-w-6xl px-6 py-10 grid grid-cols-2 md:grid-cols-4 gap-8 items-center text-center">
          <div className="flex flex-col items-center gap-2">
            <Award className="text-primary" />
            <p className="text-xs uppercase tracking-widest text-muted-foreground">TripAdvisor</p>
            <p className="font-serif text-lg">Travelers' Choice 2024</p>
          </div>
          <div className="flex flex-col items-center gap-2">
            <Star className="text-primary" />
            <p className="text-xs uppercase tracking-widest text-muted-foreground">Recomendación</p>
            <p className="font-serif text-lg">96 % · 1,810 reseñas</p>
          </div>
          <div className="flex flex-col items-center gap-2">
            <Leaf className="text-primary" />
            <p className="text-xs uppercase tracking-widest text-muted-foreground">Filosofía</p>
            <p className="font-serif text-lg">Ingredientes naturales</p>
          </div>
          <div className="flex flex-col items-center gap-2">
            <Mountain className="text-primary" />
            <p className="text-xs uppercase tracking-widest text-muted-foreground">Concepto</p>
            <p className="font-serif text-lg">Alpino · Andino</p>
          </div>
        </div>
      </section>

      {/* HISTORY INTRO */}
      <section className="mx-auto max-w-7xl px-6 py-24 grid md:grid-cols-2 gap-16 items-center">
        <div>
          <span className="divider-zz mb-5">Nuestra Esencia</span>
          <h2 className="font-serif text-4xl md:text-5xl leading-tight">
            Dos cordilleras, una mesa.
          </h2>
          <p className="mt-6 text-muted-foreground leading-relaxed">
            Nacimos del encuentro entre la tradición de los Alpes suizos y la riqueza ancestral de los Andes peruanos. Cada plato es una conversación entre técnicas centenarias e ingredientes que viajan desde valles altos hasta nuestra cocina en el corazón de Arequipa.
          </p>
          <p className="mt-4 text-muted-foreground leading-relaxed">
            Carnes premium, quinua, papas nativas, quesos artesanales y hierbas de montaña: la geografía hecha gastronomía.
          </p>
          <Link
            to="/historia"
            className="mt-8 inline-block text-primary text-sm tracking-wider uppercase border-b border-primary pb-1 hover:text-accent hover:border-accent"
          >
            Conoce nuestra historia
          </Link>
        </div>
        <div className="relative">
          <img src={interior} alt="Interior de ZigZag" className="w-full h-[520px] object-cover" loading="lazy" />
          <div className="absolute -bottom-6 -left-6 hidden md:block bg-primary text-primary-foreground p-6 max-w-xs">
            <p className="font-display text-lg">"Una bóveda de sillar de 400 años, transformada en escenario gastronómico."</p>
          </div>
        </div>
      </section>

      {/* SIGNATURE DISHES */}
      <section className="bg-card py-24">
        <div className="mx-auto max-w-7xl px-6">
          <SectionTitle
            eyebrow="Especialidades"
            title="Platos que cuentan historias"
            subtitle="Una selección de creaciones que definen la identidad ZigZag."
          />
          <div className="mt-16 grid md:grid-cols-3 gap-8">
            {[
              { img: dishSteak, name: "Lomo Andino", desc: "Lomo fino madurado, reducción de vino tinto y hierbas de altura." },
              { img: dishFondue, name: "Fondue Alpina", desc: "Quesos suizos fundidos con un toque andino: rocoto suave y pan de quinua." },
              { img: dishCeviche, name: "Trucha del Titicaca", desc: "Trucha fresca curada con leche de tigre, cancha serrana y ají amarillo." },
            ].map((d) => (
              <article key={d.name} className="group">
                <div className="overflow-hidden">
                  <img
                    src={d.img}
                    alt={d.name}
                    className="w-full h-80 object-cover transition-transform duration-700 group-hover:scale-105"
                    loading="lazy"
                  />
                </div>
                <h3 className="font-serif text-2xl mt-6">{d.name}</h3>
                <p className="mt-2 text-sm text-muted-foreground">{d.desc}</p>
              </article>
            ))}
          </div>
          <div className="text-center mt-14">
            <Link
              to="/menu"
              className="inline-block border border-primary text-primary px-8 py-3.5 text-xs uppercase tracking-[0.25em] hover:bg-primary hover:text-primary-foreground transition-colors"
            >
              Explorar el menú completo
            </Link>
          </div>
        </div>
      </section>

      {/* LANDSCAPE BANNER */}
      <section className="relative h-[60vh] min-h-[420px] overflow-hidden">
        <img src={landscape} alt="Cordilleras" className="absolute inset-0 w-full h-full object-cover" loading="lazy" />
        <div className="absolute inset-0 bg-gradient-to-r from-black/70 via-black/40 to-transparent" />
        <div className="relative z-10 h-full flex items-center px-6 md:px-20">
          <div className="max-w-xl text-primary-foreground">
            <span className="divider-zz text-gold mb-4">Filosofía</span>
            <h2 className="font-serif text-4xl md:text-5xl leading-tight">
              De la montaña al plato, sin atajos.
            </h2>
            <p className="mt-5 text-primary-foreground/85">
              Trabajamos con productores locales y técnicas honestas. Sabores limpios, presentación artística, hospitalidad arequipeña.
            </p>
          </div>
        </div>
      </section>

      {/* TESTIMONIALS */}
      <section className="mx-auto max-w-6xl px-6 py-24">
        <SectionTitle eyebrow="Testimonios" title="Voces de nuestros comensales" />
        <div className="mt-14 grid md:grid-cols-3 gap-8">
          {[
            { q: "Una experiencia inolvidable. La fusión funciona a la perfección y el ambiente bajo la bóveda es mágico.", a: "María L." },
            { q: "El mejor lomo que hemos probado en Perú. Servicio impecable y vinos extraordinarios.", a: "Andreas K." },
            { q: "Cocina honesta, ingredientes brillantes. Volveremos cada vez que estemos en Arequipa.", a: "Elena R." },
          ].map((t) => (
            <blockquote key={t.a} className="bg-card p-8 border border-border">
              <div className="flex gap-1 text-gold mb-4">
                {Array.from({ length: 5 }).map((_, i) => <Star key={i} size={14} fill="currentColor" />)}
              </div>
              <p className="font-display text-lg leading-relaxed text-foreground/90">"{t.q}"</p>
              <footer className="mt-5 text-xs uppercase tracking-widest text-muted-foreground">— {t.a}</footer>
            </blockquote>
          ))}
        </div>
      </section>

      {/* RESERVATION CTA */}
      <section className="bg-primary text-primary-foreground">
        <div className="mx-auto max-w-5xl px-6 py-20 text-center">
          <span className="divider-zz text-gold mb-4">Reservas</span>
          <h2 className="font-serif text-4xl md:text-5xl">Una mesa te espera</h2>
          <p className="mt-5 text-primary-foreground/85 max-w-xl mx-auto">
            Cenas íntimas, celebraciones especiales o un almuerzo memorable. Reserva tu lugar en una de las experiencias gastronómicas más queridas de Arequipa.
          </p>
          <Link
            to="/reservas"
            className="mt-10 inline-block bg-primary-foreground text-primary px-10 py-4 text-xs uppercase tracking-[0.25em] hover:bg-gold hover:text-foreground transition-colors"
          >
            Reservar ahora
          </Link>
        </div>
      </section>
    </>
  );
}
