import os
import customtkinter as ctk
from tkinter import filedialog, messagebox
from PIL import Image
import img2pdf

# ضبط المظهر العام للواجهة
ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

class ImageToPdfApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("محول الصور إلى PDF (مقاس A4 دقيق)")
        self.geometry("500x350")
        self.resizable(False, False)

        self.selected_image_paths = []

        # العنوان الرئيسي
        self.label_title = ctk.CTkLabel(
            self, 
            text="تحويل الصور إلى PDF بحجم A4", 
            font=ctk.CTkFont(size=20, weight="bold")
        )
        self.label_title.pack(pady=20)

        # زر اختيار الصور
        self.btn_select = ctk.CTkButton(
            self, 
            text="📁 اختيار الصور من الجهاز", 
            command=self.select_images,
            font=ctk.CTkFont(size=15)
        )
        self.btn_select.pack(pady=10)

        # نص يعرض عدد الصور المختارة
        self.label_status = ctk.CTkLabel(
            self, 
            text="لم يتم اختيار أي صور بعد", 
            text_color="gray",
            font=ctk.CTkFont(size=13)
        )
        self.label_status.pack(pady=10)

        # زر التحويل والحفظ
        self.btn_convert = ctk.CTkButton(
            self, 
            text="⚡ تحويل وحفظ كـ PDF", 
            command=self.convert_to_pdf,
            fg_color="green",
            hover_color="darkgreen",
            font=ctk.CTkFont(size=15, weight="bold"),
            state="disabled"
        )
        self.btn_convert.pack(pady=20)

    def select_images(self):
        # فتح نافذة اختيار الملفات لتحديد الصور (يمكن اختيار صورة أو أكثر)
        file_types = [("ملفات الصور", "*.jpg *.jpeg *.png *.webp *.bmp")]
        paths = filedialog.askopenfilenames(title="اختر الصور", filetypes=file_types)

        if paths:
            self.selected_image_paths = list(paths)
            count = len(self.selected_image_paths)
            self.label_status.configure(
                text=f"تم اختيار {count} صورة/صور جاهزة للتحويل", 
                text_color="white"
            )
            self.btn_convert.configure(state="normal")

    def convert_to_pdf(self):
        if not self.selected_image_paths:
            return

        # تحديد مكان اسم ومسار حفظ ملف الـ PDF الناتج
        save_path = filedialog.asksaveasfilename(
            defaultextension=".pdf",
            filetypes=[("ملف PDF", "*.pdf")],
            title="اختر مكان حفظ ملف PDF"
        )

        if not save_path:
            return

        try:
            # ضبط مقاس A4 الدقيق بالنقاط (210mm x 297mm)
            a4_size = (img2pdf.mm_to_pt(210), img2pdf.mm_to_pt(297))
            layout_fun = img2pdf.get_layout_fun(a4_size)

            # تحويل الصور مباشرة دون ضغط للحد من فقدان الجودة
            with open(save_path, "wb") as f:
                f.write(img2pdf.convert(self.selected_image_paths, layout_fun=layout_fun))

            messagebox.showinfo("نجاح", "تم تحويل الصور بنجاح إلى ملف PDF بحجم A4 وبأعلى جودة!")
            
            # إعادة ضبط الواجهة
            self.selected_image_paths = []
            self.label_status.configure(text="لم يتم اختيار أي صور بعد", text_color="gray")
            self.btn_convert.configure(state="disabled")

        except Exception as e:
            messagebox.showerror("خطأ", f"حدث خطأ أثناء التحويل:\n{str(e)}")

if __name__ == "__main__":
    app = ImageToPdfApp()
    app.mainloop()
