import { createFileRoute } from "@tanstack/react-router";
import { SectionTitle } from "@/components/SectionTitle";
import dishSteak from "@/assets/dish-steak.jpg";
import dishFondue from "@/assets/dish-fondue.jpg";
import dishCeviche from "@/assets/dish-ceviche.jpg";
import dishDessert from "@/assets/dish-dessert.jpg";

export const Route = createFileRoute("/menu")({
  head: () => ({
    meta: [
      { title: "Menú — ZigZag Restaurant Arequipa" },
      { name: "description", content: "Descubre el menú alpino-andino de ZigZag: entrantes, carnes premium, especialidades, postres y vinos seleccionados." },
      { property: "og:title", content: "Menú — ZigZag Restaurant" },
      { property: "og:description", content: "Cocina alpina y andina en el Centro Histórico de Arequipa." },
      { property: "og:image", content: dishSteak },
    ],
  }),
  component: MenuPage,
});

const sections = [
  {
    title: "Entrantes",
    img: dishCeviche,
    items: [
      { name: "Trucha del Titicaca curada", price: "S/ 38", desc: "Trucha fresca, leche de tigre suave, cancha serrana, ají amarillo." },
      { name: "Carpaccio de alpaca", price: "S/ 42", desc: "Lonjas finas con aceite de huacatay, queso paria y nueces." },
      { name: "Sopa de quinua y poro", price: "S/ 28", desc: "Crema cremosa con quinua tricolor y aceite de oliva del valle." },
      { name: "Tabla de quesos alpinos", price: "S/ 58", desc: "Selección suiza con miel andina y panes artesanales." },
    ],
  },
  {
    title: "Steakhouse",
    img: dishSteak,
    items: [
      { name: "Lomo Andino", price: "S/ 92", desc: "Lomo fino madurado, reducción de vino tinto, hierbas de altura." },
      { name: "Bife de chorizo a las brasas", price: "S/ 88", desc: "Cocción al carbón, chimichurri andino, papas nativas." },
      { name: "Filete Mignon ZigZag", price: "S/ 110", desc: "Reducción de oporto, jugo de carne, espárragos verdes." },
      { name: "Costillar de cordero", price: "S/ 98", desc: "Marinado en hierbas alpinas, puré de olluco, jus de romero." },
    ],
  },
  {
    title: "Especialidades Alpinas y Andinas",
    img: dishFondue,
    items: [
      { name: "Fondue Alpina ZigZag", price: "S/ 110", desc: "Quesos suizos fundidos, rocoto suave, pan de quinua." },
      { name: "Raclette de la Casa", price: "S/ 95", desc: "Queso fundido sobre papas nativas y embutidos artesanales." },
      { name: "Quinotto de hongos", price: "S/ 62", desc: "Quinua cremosa, hongos del bosque, parmesano añejo." },
      { name: "Trucha en costra de quinua", price: "S/ 72", desc: "Filete de trucha, costra crocante, salsa de maracuyá serrano." },
    ],
  },
  {
    title: "Postres",
    img: dishDessert,
    items: [
      { name: "Volcán de cacao andino", price: "S/ 32", desc: "Bizcocho fundido de cacao, helado de vainilla, flores comestibles." },
      { name: "Tarta de manzana alpina", price: "S/ 28", desc: "Receta tradicional suiza, canela, crema batida ligera." },
      { name: "Suspiro de lúcuma", price: "S/ 26", desc: "Versión moderna del clásico peruano con merengue tostado." },
    ],
  },
];

function MenuPage() {
  return (
    <div>
      <section className="bg-secondary text-secondary-foreground py-24 text-center px-6">
        <span className="divider-zz text-gold mb-5">La Carta</span>
        <h1 className="font-serif text-5xl md:text-6xl">Nuestro Menú</h1>
        <p className="mt-5 max-w-2xl mx-auto text-secondary-foreground/80">
          Una carta viva que cambia con la temporada y los productos de los pequeños productores que confían en nosotros.
        </p>
      </section>

      <div className="mx-auto max-w-6xl px-6 py-20 space-y-24">
        {sections.map((s, i) => (
          <section key={s.title} className={`grid md:grid-cols-2 gap-12 items-start ${i % 2 ? "md:[&>div:first-child]:order-2" : ""}`}>
            <div>
              <img src={s.img} alt={s.title} className="w-full h-[420px] object-cover" loading="lazy" />
            </div>
            <div>
              <SectionTitle eyebrow={`0${i + 1}`} title={s.title} align="left" />
              <ul className="mt-10 space-y-6">
                {s.items.map((it) => (
                  <li key={it.name} className="border-b border-border pb-5">
                    <div className="flex justify-between gap-4 items-baseline">
                      <h3 className="font-serif text-xl text-foreground">{it.name}</h3>
                      <span className="font-serif text-lg text-primary whitespace-nowrap">{it.price}</span>
                    </div>
                    <p className="mt-1 text-sm text-muted-foreground">{it.desc}</p>
                  </li>
                ))}
              </ul>
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
