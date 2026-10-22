-- ============================================================
-- MIGRACIÓN: alarma de stock bajo por variante (producto + tamaño)
-- Idempotente: se puede correr las veces que haga falta.
--
-- alarma_stock = umbral. Cuando stock <= alarma_stock, el admin
-- marca la variante en rojo. Vacío (null) = sin alarma.
-- ============================================================

alter table public.producto_precios
    add column if not exists alarma_stock integer;

alter table public.producto_precios
    drop constraint if exists producto_precios_alarma_stock_check;

alter table public.producto_precios
    add constraint producto_precios_alarma_stock_check
    check (alarma_stock is null or alarma_stock >= 0);
