"use client";

import { useState } from "react";
import Image from "next/image";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

interface ImageSlot {
  label: string;
  url: string;
}

/** Click-to-enlarge grid for the three review images. URLs are the
 * short-lived signed URLs `getIdentityVerificationDetail` generates —
 * this component never fetches or caches them beyond the single page
 * load that already has them in props. */
export function IdentityVerificationImages({
  idFrontUrl,
  idBackUrl,
  selfieWithIdUrl,
}: {
  idFrontUrl: string;
  idBackUrl: string;
  selfieWithIdUrl: string;
}) {
  const [openImage, setOpenImage] = useState<ImageSlot | null>(null);

  const slots: ImageSlot[] = [
    { label: "ID — ön üz", url: idFrontUrl },
    { label: "ID — arxa üz", url: idBackUrl },
    { label: "Selfie", url: selfieWithIdUrl },
  ];

  return (
    <>
      <div className="grid grid-cols-3 gap-3">
        {slots.map((slot) => (
          <button
            key={slot.label}
            type="button"
            onClick={() => setOpenImage(slot)}
            className="group flex flex-col gap-1.5 text-left"
          >
            <div className="relative aspect-[3/4] overflow-hidden rounded-lg border bg-muted">
              <Image
                src={slot.url}
                alt={slot.label}
                fill
                sizes="200px"
                className="object-cover transition-transform group-hover:scale-105"
                unoptimized
              />
            </div>
            <span className="text-xs text-muted-foreground">{slot.label}</span>
          </button>
        ))}
      </div>

      <Dialog open={openImage != null} onOpenChange={(open) => !open && setOpenImage(null)}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>{openImage?.label}</DialogTitle>
          </DialogHeader>
          {openImage && (
            <div className="relative aspect-[3/4] w-full overflow-hidden rounded-lg">
              <Image src={openImage.url} alt={openImage.label} fill sizes="600px" className="object-contain" unoptimized />
            </div>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
