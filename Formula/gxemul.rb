require "formula"

class Gxemul < Formula
  homepage "http://gxemul.sourceforge.net"
  url "http://gxemul.sourceforge.net/src/gxemul-0.6.0.1.tar.gz"
  sha1 "8a9b7a6c08628c2a59a6e7e9c7c449c3826b4744"

  depends_on :x11

  patch :DATA

  def install
    system "./configure"
    system "make"
    bin.install "gxemul"
    man1.install "man/gxemul.1"
  end
end

__END__
diff -urw gxemul-0.6.0.1/src/components/cpu/M88K_CPUComponent.cc gxemul-0.6.0.1-osx/src/components/cpu/M88K_CPUComponent.cc
--- gxemul-0.6.0.1/src/components/cpu/M88K_CPUComponent.cc	2014-08-17 10:45:14.000000000 +0200
+++ gxemul-0.6.0.1-osx/src/components/cpu/M88K_CPUComponent.cc	2014-09-01 15:07:04.000000000 +0200
@@ -337,7 +337,7 @@
 }


-void (*M88K_CPUComponent::GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*) const
+void (*M88K_CPUComponent::GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*)
 {
 	return instr_ToBeTranslated;
 }
diff -urw gxemul-0.6.0.1/src/components/cpu/MIPS_CPUComponent.cc gxemul-0.6.0.1-osx/src/components/cpu/MIPS_CPUComponent.cc
--- gxemul-0.6.0.1/src/components/cpu/MIPS_CPUComponent.cc	2014-08-17 10:45:14.000000000 +0200
+++ gxemul-0.6.0.1-osx/src/components/cpu/MIPS_CPUComponent.cc	2014-09-01 15:08:22.000000000 +0200
@@ -327,7 +327,7 @@
 }


-void (*MIPS_CPUComponent::GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*) const
+void (*MIPS_CPUComponent::GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*)
 {
 	bool mips16 = m_pc & 1? true : false;
 	return mips16? instr_ToBeTranslated_MIPS16 : instr_ToBeTranslated;
diff -urw gxemul-0.6.0.1/src/include/components/CPUDyntransComponent.h gxemul-0.6.0.1-osx/src/include/components/CPUDyntransComponent.h
--- gxemul-0.6.0.1/src/include/components/CPUDyntransComponent.h	2014-08-17 10:45:13.000000000 +0200
+++ gxemul-0.6.0.1-osx/src/include/components/CPUDyntransComponent.h	2014-09-01 15:02:04.000000000 +0200
@@ -105,7 +105,7 @@
 protected:
 	// Implemented by specific CPU families:
 	virtual int GetDyntransICshift() const = 0;
-	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent* cpu, DyntransIC* ic) const = 0;
+	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent* cpu, DyntransIC* ic) = 0;

 	void DyntransToBeTranslatedBegin(struct DyntransIC*);
 	bool DyntransReadInstruction(uint16_t& iword);
diff -urw gxemul-0.6.0.1/src/include/components/M88K_CPUComponent.h gxemul-0.6.0.1-osx/src/include/components/M88K_CPUComponent.h
--- gxemul-0.6.0.1/src/include/components/M88K_CPUComponent.h	2014-08-17 10:45:13.000000000 +0200
+++ gxemul-0.6.0.1-osx/src/include/components/M88K_CPUComponent.h	2014-09-01 15:06:26.000000000 +0200
@@ -377,7 +377,7 @@
 	virtual bool FunctionTraceReturnImpl(int64_t& retval) { retval = m_r[M88K_RETURN_VALUE_REG]; return true; }

 	virtual int GetDyntransICshift() const;
-	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*) const;
+	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*);

 	virtual void ShowRegisters(GXemul* gxemul, const vector<string>& arguments) const;

diff -urw gxemul-0.6.0.1/src/include/components/MIPS_CPUComponent.h gxemul-0.6.0.1-osx/src/include/components/MIPS_CPUComponent.h
--- gxemul-0.6.0.1/src/include/components/MIPS_CPUComponent.h	2014-08-17 10:45:13.000000000 +0200
+++ gxemul-0.6.0.1-osx/src/include/components/MIPS_CPUComponent.h	2014-09-01 15:07:38.000000000 +0200
@@ -196,7 +196,7 @@
 	virtual bool FunctionTraceReturnImpl(int64_t& retval);

 	virtual int GetDyntransICshift() const;
-	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*) const;
+	virtual void (*GetDyntransToBeTranslated())(CPUDyntransComponent*, DyntransIC*);

 	virtual void ShowRegisters(GXemul* gxemul, const vector<string>& arguments) const;

