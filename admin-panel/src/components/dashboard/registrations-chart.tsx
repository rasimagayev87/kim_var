"use client";

import { Bar, BarChart, CartesianGrid, XAxis } from "recharts";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/components/ui/chart";
import type { RegistrationDay } from "@/lib/data/dashboard";

const chartConfig = {
  count: {
    label: "Qeydiyyat",
    color: "var(--primary)",
  },
} satisfies ChartConfig;

const WEEKDAY_LABELS = ["Baz", "B.e", "Ç.a", "Çər", "C.a", "Cüm", "Şən"];

export function RegistrationsChart({ data }: { data: RegistrationDay[] }) {
  const chartData = data.map((day) => ({
    ...day,
    label: WEEKDAY_LABELS[new Date(day.date).getDay()],
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>Son 7 gün — yeni qeydiyyatlar</CardTitle>
        <CardDescription>Hər gün tamamlanan onboarding sayı</CardDescription>
      </CardHeader>
      <CardContent>
        <ChartContainer config={chartConfig} className="h-64 w-full">
          <BarChart data={chartData}>
            <CartesianGrid vertical={false} />
            <XAxis dataKey="label" tickLine={false} axisLine={false} tickMargin={8} />
            <ChartTooltip
              cursor={false}
              content={<ChartTooltipContent labelKey="date" />}
            />
            <Bar dataKey="count" fill="var(--color-count)" radius={4} />
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
  );
}
