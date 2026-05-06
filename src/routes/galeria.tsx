import { createFileRoute } from "@tanstack/react-router";
import { SectionTitle } from "@/components/SectionTitle";
import interior from "@/assets/interior.jpg";
import dishSteak from "@/assets/dish-steak.jpg";
import dishFondue from "@/assets/dish-fondue.jpg";
import dishCeviche from "@/assets/dish-ceviche.jpg";
import dishDessert from "@/assets/dish-dessert.jpg";
import landscape from "@/assets/landscape.jpg";
import heroDish from "@/assets/hero-dish.jpg";

export const Route = createFileRoute("/galeria")({
  head: () => ({
    meta: [
      { title: "Galería — ZigZag Restaurant" },
      { name: "description", content: "Ambiente, platos y atmósfera de ZigZag Restaurant en Arequipa." },
      { property: "og:title", content: "Galería — ZigZag Restaurant" },
      { property: "og:description", content: "El espacio, los platos, los detalles." },
      { property: "og:image", content: interior },
    ],
  }),
  component: GalleryPage,
});

const images = [
  { src: interior, alt: "Salón principal", span: "md:col-span-2 md:row-span-2" },
  { src: dishSteak, alt: "Lomo Andino" },
  { src: dishFondue, alt: "Fondue Alpina" },
  { src: dishCeviche, alt: "Trucha del Titicaca" },
  { src: heroDish, alt: "Plato firma" },
  { src: landscape, alt: "Cordilleras", span: "md:col-span-2" },
  { src: dishDessert, alt: "Volcán de cacao" },
];

function GalleryPage() {
  return (
    <div>
      <section className="py-20 text-center px-6">
        <SectionTitle eyebrow="Galería" title="Atmósfera y detalle" subtitle="Un recorrido visual por nuestro espacio, nuestros platos y nuestro espíritu." />
      </section>
      <div className="mx-auto max-w-7xl px-6 pb-24 grid grid-cols-2 md:grid-cols-4 auto-rows-[220px] gap-4">
        {images.map((im, i) => (
          <div key={i} className={`overflow-hidden ${im.span ?? ""}`}>
            <img src={im.src} alt={im.alt} className="w-full h-full object-cover hover:scale-105 transition-transform duration-700" loading="lazy" />
          </div>
        ))}
      </div>
    </div>
  );
}
