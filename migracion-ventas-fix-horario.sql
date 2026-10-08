-- ============================================================
-- FIX: registrar_venta_whatsapp_lote usaba current_date/current_time,
-- que toman el timezone del SERVIDOR (UTC en Supabase por defecto),
-- no el de Argentina. Se reemplaza por una conversión explícita.
-- Idempotente: se puede correr las veces que haga falta.
-- ============================================================

create or replace function public.registrar_venta_whatsapp_lote(p_items jsonb)
returns void
language plpgsql
security definer
as $$
declare
    v_item jsonb;
    v_producto_precio_id bigint;
    v_cantidad integer;
    v_current_stock integer;
    v_ahora timestamp;
begin
    v_ahora := now() AT TIME ZONE 'America/Argentina/Buenos_Aires';

    for v_item in select * from jsonb_array_elements(p_items)
    loop
        v_producto_precio_id := (v_item->>'producto_precio_id')::bigint;
        v_cantidad := (v_item->>'cantidad')::integer;

        if v_producto_precio_id is not null then
            select stock into v_current_stock
            from public.producto_precios
            where id = v_producto_precio_id
            for update;

            if v_current_stock is not null then
                if v_current_stock < v_cantidad then
                    raise exception 'Stock insuficiente para %', v_item->>'producto_nombre';
                end if;

                update public.producto_precios
                set stock = stock - v_cantidad, updated_at = now()
                where id = v_producto_precio_id;
            end if;
        end if;

        insert into public.ventas (
            fecha, hora, rubro_nombre, producto_nombre, tamanio_nombre,
            cantidad, precio_unitario, precio_total,
            producto_precio_id, promocion_id, venta_grupo_id, origen
        ) values (
            v_ahora::date, v_ahora::time,
            v_item->>'rubro_nombre', v_item->>'producto_nombre', v_item->>'tamanio_nombre',
            v_cantidad, (v_item->>'precio_unitario')::numeric,
            (v_item->>'precio_unitario')::numeric * v_cantidad,
            v_producto_precio_id,
            (v_item->>'promocion_id')::bigint,
            (v_item->>'venta_grupo_id')::uuid,
            'whatsapp'
        );
    end loop;
end;
$$;

grant execute on function public.registrar_venta_whatsapp_lote(jsonb) to anon, authenticated;
