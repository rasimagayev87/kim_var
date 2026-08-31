import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type {
  CohortActivity,
  ContentCounts,
  EngagementMetrics,
  RegistrationCounts,
  RevenueTotals,
  SeriesPoint,
  SubscriptionTierBreakdown,
} from "@/lib/data/analytics";

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-lg border p-4">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
      {hint ? <p className="mt-1 text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

function n(value: number): string {
  return value.toLocaleString("az-AZ");
}

function azn(value: number): string {
  return `${value.toLocaleString("az-AZ", { maximumFractionDigits: 2 })} AZN`;
}

export function EngagementPanel({ metrics }: { metrics: EngagementMetrics }) {
  return (
    <section className="space-y-2">
      <div>
        <h2 className="text-lg font-medium">Aktiv istifadəçilər</h2>
        <p className="text-sm text-muted-foreground">
          <code>lastSeen</code> sahəsinə görə — yəni &quot;son dəfə görülüb&quot;, &quot;hazırda
          onlayn&quot; deyil. Tətbiqi zorla bağlayan cihaz bu sahəni yeniləmir, ona görə rəqəm
          bir qədər yuxarı meyillidir.
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <Stat label="DAU — son 24 saat" value={n(metrics.dau)} />
        <Stat label="WAU — son 7 gün" value={n(metrics.wau)} />
        <Stat label="MAU — son 30 gün" value={n(metrics.mau)} />
      </div>
    </section>
  );
}

export function RegistrationPanel({
  counts,
  series,
}: {
  counts: RegistrationCounts;
  series: SeriesPoint[];
}) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-medium">Yeni qeydiyyatlar</h2>
      <div className="grid gap-3 sm:grid-cols-3">
        <Stat label="Bu gün" value={n(counts.today)} />
        <Stat label="Son 7 gün" value={n(counts.last7Days)} />
        <Stat label="Son 30 gün" value={n(counts.last30Days)} />
      </div>
      <Sparkline points={series} label="Gündəlik qeydiyyat, son 30 gün" format={n} />
    </section>
  );
}

export function ContentPanel({ counts }: { counts: ContentCounts }) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-medium">Aktiv məzmun</h2>
      <div className="grid gap-3 sm:grid-cols-4">
        <Stat label="Məkanlar" value={n(counts.activeVenues)} hint="status: approved" />
        <Stat label="Təkliflər" value={n(counts.activeOffers)} hint="status: approved" />
        <Stat label="PinBox" value={n(counts.activePinBoxes)} hint="status: active" />
        <Stat label="Tədbirlər" value={n(counts.activeEvents)} hint="upcoming / live" />
      </div>
    </section>
  );
}

export function RevenuePanel({
  totals,
  series,
  tiers,
}: {
  totals: RevenueTotals;
  series: SeriesPoint[];
  tiers: SubscriptionTierBreakdown[];
}) {
  return (
    <section className="space-y-2">
      <div>
        <h2 className="text-lg font-medium">Gəlir</h2>
        <p className="text-sm text-muted-foreground">
          Yalnız <code>status: completed</code> ödənişlər. Geri qaytarılmış məbləğlər çıxılmır.
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <Stat label="Bu gün" value={azn(totals.today)} />
        <Stat label="Son 7 gün" value={azn(totals.last7Days)} />
        <Stat label="Son 30 gün" value={azn(totals.last30Days)} />
      </div>
      <Sparkline points={series} label="Gündəlik gəlir, son 30 gün" format={azn} />

      <div className="pt-2">
        <h3 className="text-sm font-medium">Abunəliklər — aylıq tarif üzrə</h3>
        <p className="mb-2 text-sm text-muted-foreground">
          Təsdiqlənmiş məkanlar, kateqoriyanın aylıq qiymətinə görə qruplaşdırılıb.
        </p>
        <div className="overflow-x-auto rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Aylıq tarif</TableHead>
                <TableHead className="text-right">Məkan sayı</TableHead>
                <TableHead className="text-right">Bu tarifdəki kateqoriyalar</TableHead>
                <TableHead className="text-right">Aylıq cəm</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {tiers.map((tier) => (
                <TableRow key={tier.feeAzn}>
                  <TableCell className="tabular-nums">{azn(tier.feeAzn)}</TableCell>
                  <TableCell className="text-right tabular-nums">{n(tier.venues)}</TableCell>
                  <TableCell className="text-right tabular-nums text-muted-foreground">
                    {n(tier.categoryCount)}
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {azn(tier.feeAzn * tier.venues)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </div>
    </section>
  );
}

export function CohortPanel({ cohorts, windowDays }: { cohorts: CohortActivity[]; windowDays: number }) {
  return (
    <section className="space-y-2">
      <div>
        {/*
          NOT titled "Retention", deliberately. What this measures is a
          snapshot, not a curve — see `getCohortActivity`'s own comment.
          The heading says what was actually counted so nobody reads a
          retention rate into it.
        */}
        <h2 className="text-lg font-medium">
          Qeydiyyat ayına görə — son {windowDays} gündə aktiv olanlar
        </h2>
        <p className="text-sm text-muted-foreground">
          Hər sətir: həmin ayda qeydiyyatdan keçən hesablar, və onlardan neçəsinin{" "}
          <code>lastSeen</code> dəyəri son {windowDays} gün içindədir. Bu, retention əyrisi{" "}
          <strong>deyil</strong> — anlıq şəkildir: sxem hər hesab üçün yalnız bir{" "}
          <code>lastSeen</code> saxlayır, ona görə hər gün gəlib dünən dayanan istifadəçi ilə
          yalnız dünən bir dəfə açan istifadəçi burada eyni görünür.
        </p>
      </div>
      <div className="overflow-x-auto rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Qeydiyyat ayı</TableHead>
              <TableHead className="text-right">Qeydiyyat</TableHead>
              <TableHead className="text-right">Son {windowDays} gündə aktiv</TableHead>
              <TableHead className="text-right">Nisbət</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {cohorts.map((c) => (
              <TableRow key={c.month}>
                <TableCell className="tabular-nums">{c.month}</TableCell>
                <TableCell className="text-right tabular-nums">{n(c.registered)}</TableCell>
                <TableCell className="text-right tabular-nums">{n(c.stillActive)}</TableCell>
                <TableCell className="text-right tabular-nums">
                  {c.registered === 0 ? "—" : `${Math.round((c.stillActive / c.registered) * 100)}%`}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </section>
  );
}

/** Bar chart with no chart library — the data is one number per day. */
function Sparkline({
  points,
  label,
  format,
}: {
  points: SeriesPoint[];
  label: string;
  format: (v: number) => string;
}) {
  const max = Math.max(1, ...points.map((p) => p.value));
  return (
    <div className="rounded-lg border p-4">
      <p className="mb-3 text-sm text-muted-foreground">{label}</p>
      <div className="flex h-24 items-end gap-[2px]">
        {points.map((p) => (
          <div
            key={p.date}
            title={`${p.date}: ${format(p.value)}`}
            className="flex-1 rounded-t bg-primary/70"
            style={{ height: `${Math.max(2, (p.value / max) * 100)}%` }}
          />
        ))}
      </div>
      <div className="mt-2 flex justify-between text-xs text-muted-foreground">
        <span>{points[0]?.date}</span>
        <span>ən yüksək: {format(max)}</span>
        <span>{points[points.length - 1]?.date}</span>
      </div>
    </div>
  );
}
