from enum import Enum, auto

class OpcodeComponent:
    pass

class b(OpcodeComponent):
    """
    Some constant bits
    """
    def __init__(self, bits):
        """
        :param bits: String with binary representation of constant bits. Length should correspond to
        number of bits (do not skip leading zeros).
        """
        super().__init__()
        #XXX

class imm(OpcodeComponent):
    """
    Some chunk of immediate value.
    """
    def __init__(self, hiBit, loBit=None, isUnsigned=False):
        """
        :param hiBit: Index of high-ordered bit of the chunk.
        :param loBit: Index of low-ordered bit of the chunk, None if one bit chunk.
        """
        super().__init__()
        #XXX

def uimm(hiBit, loBit=None):
    """
    Chunk of unsigned immediate value.
    """
    return imm(hiBit, loBit, True)

class RegType(Enum):
    SRC1 = auto()
    SRC2 = auto()
    DST = auto()
    SRC_DST = auto()

class RegReference(OpcodeComponent):
    def __init__(self, regType, isCompressed=False):
        super().__init__()

def rs1():
    return RegReference(RegType.SRC1)

def rs2():
    return RegReference(RegType.SRC2)

def rd():
    return RegReference(RegType.DST)

def rsd():
    return RegReference(RegType.SRC_DST)

def rs1p():
    return RegReference(RegType.SRC1, True)

def rs2p():
    return RegReference(RegType.SRC2, True)

def rdp():
    return RegReference(RegType.DST, True)

def rsdp():
    return RegReference(RegType.SRC_DST, True)

def cmd(name, mapTo, *components):
    print(components)


def DefineCommands():
    

    cmd("C.ADDI4SPN",
        b("000"), uimm(4,5), uimm(9,6), uimm(2), uimm(3), rdp(), b("00"))
    cmd("C.LW",
        b("010"), uimm(5,3), rs1p(), uimm(2), uimm(6), rdp(), b("00"))
    cmd("C.SW",
        b("110"), uimm(5,3), rs1p(), uimm(2), uimm(6), rdp(), b("00"))

    # No special handling for C.NOP - translate it to `ADDI x0, x0, 0`
    cmd("C.ADDI",
        b("000"), imm(5), rsd(), imm(4,0), b("01"))
    cmd("C.JAL",
        b("001"), imm(11), imm(4), imm(9,8), imm(10), imm(6), imm(7), imm(3,1), imm(5), b("01"))
    cmd("C.LI",
        b("010"), imm(5), rd(), imm(4,0), b("01"))
    cmd("C.ADDI16SP",
        b("011", imm(9), b("00010"), imm(4), imm(6), imm(8,7), imm(5), b("01")))
    cmd("C.LUI",
        b("011", imm(17), rd(), imm(16,12), b("01")))
    cmd("C.SRLI",
        b("100"), b("0"), b("00"), rsdp(), uimm(4,0), b("01"))
    cmd("C.SRAI",
        b("100"), b("0"), b("01"), rsdp(), uimm(4,0), b("01"))
    cmd("C.ANDI",
        b("100"), imm(5), b("10"), rsdp(), imm(4,0), b("01"))
    cmd("C.SUB",
        b("100"), b("0"), b("11"), rsdp(), b("00"), rs2p(), b("01"))
    cmd("C.XOR",
        b("100"), b("0"), b("11"), rsdp(), b("01"), rs2p(), b("01"))
    cmd("C.OR",
        b("100"), b("0"), b("11"), rsdp(), b("10"), rs2p(), b("01"))
    cmd("C.AND",
        b("100"), b("0"), b("11"), rsdp(), b("11"), rs2p(), b("01"))
    cmd("C.J",
        b("101"), imm(11), imm(4), imm(9,8), imm(10), imm(6), imm(7), imm(3,1), imm(5), b("01"))
    cmd("C.BEQZ",
        b("110"), imm(8), imm(4,3), rs1p(), imm(7,6), imm(2,1), imm(5), b("01"))
    cmd("C.BNEZ",
        b("111"), imm(8), imm(4,3), rs1p(), imm(7,6), imm(2,1), imm(5), b("01"))

    cmd("C.SLLI",
        b("000"), b("0"), rsd(), uimm(4,0), b("10"))
    cmd("C.LWSP",
        b("010", uimm(5), rd(), uimm(4,2), uimm(7,6), b("10")))
    cmd("C.JR",
        b("100"), b("0"), rs1(), b("00000"), b("10"))
    cmd("C.MV",
        b("100"), b("0"), rd(), rs2(), b("10"))
    # C.EBREAK is skipped intentionally to save resources
    cmd("C.JALR",
        b("100"), b("1"), rs1(), b("00000"), b("10"))
    cmd("C.ADD",
        b("100"), b("1"), rsd(), rs2(), b("10"))
    cmd("C.SWSP",
        b("110"), uimm(5,2), uimm(7,6), rs2(), b("10"))


def Main():
    DefineCommands()


if __name__ == "__main__":
    Main()
