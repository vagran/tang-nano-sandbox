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
    def __init__(self, hiBit=None, loBit=None, isUnsigned=False):
        """
        :param hiBit: Index of high-ordered bit of the chunk. Can be None when used as bind target.
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

def cmd32(name, *components):
    print(components)

def cmd16(name, mapTo, *components):
    print(components)

class mapTo:
    def __init__(self, cmdName, bindings=None):
        """Mapping to 32 bits command.
        :param cmdName: 32 bits command name
        :param bindings: list of tuples (field, value)
        """
        pass


def DefineCommands32():
    cmd = cmd32

    cmd("LW",
        imm(11,0), rs1(), b("010"), rd(), b("0000011"))
    cmd("SW",
        imm(11,5), rs2(), rs1(), b("010"), imm(4,0), b("0100011"))
    cmd("JAL",
        imm(20), imm(10,1), imm(11), imm(19,12), rd(), b("1101111"))
    cmd("JALR",
        imm(11,0), rs1(), b("000"), rd(), b("1100111"))
    cmd("BEQ",
        imm(12), imm(10,5), rs2(), rs1(), b("000"), imm(4,1), imm(11), b("1100011"))
    cmd("BNE",
        imm(12), imm(10,5), rs2(), rs1(), b("001"), imm(4,1), imm(11), b("1100011"))
    cmd("ADDI",
        imm(11,0), rs1(), b("000"), rd(), b("0010011"))
    cmd("LUI",
        imm(31,12), rd(), b("0110111"))
    cmd("SLLI",
        b("0000000"), uimm(4,0), rs1(), b("001"), rd(), b("0010011"))
    cmd("SRLI",
        b("0000000"), uimm(4,0), rs1(), b("101"), rd(), b("0010011"))
    cmd("SRAI",
        b("0100000"), uimm(4,0), rs1(), b("101"), rd(), b("0010011"))
    cmd("ANDI",
        imm(11,0), rs1(), b("111"), rd(), b("0010011"))
    cmd("ADD",
        b("0000000"), rs2(), rs1(), b("000"), rd(), b("0110011"))


def DefineCommands16():

    cmd = cmd16

    cmd("C.ADDI4SPN", mapTo("ADDI", [(rs1(), 2)]),
        b("000"), uimm(4,5), uimm(9,6), uimm(2), uimm(3), rdp(), b("00"))
    cmd("C.LW", mapTo("LW"),
        b("010"), uimm(5,3), rs1p(), uimm(2), uimm(6), rdp(), b("00"))
    cmd("C.SW", mapTo("SW"),
        b("110"), uimm(5,3), rs1p(), uimm(2), uimm(6), rdp(), b("00"))

    # No special handling for C.NOP - translate it to `ADDI x0, x0, 0` to save resources
    cmd("C.ADDI", mapTo("ADDI"),
        b("000"), imm(5), rsd(), imm(4,0), b("01"))
    cmd("C.JAL", mapTo("JAL", [(rd(), 1)]),
        b("001"), imm(11), imm(4), imm(9,8), imm(10), imm(6), imm(7), imm(3,1), imm(5), b("01"))
    cmd("C.LI", mapTo("ADDI", [(rs1(), 0)]),
        b("010"), imm(5), rd(), imm(4,0), b("01"))
    cmd("C.ADDI16SP", mapTo("ADDI", [(rs1(), 2), (rd(), 2)]),
        b("011"), imm(9), b("00010"), imm(4), imm(6), imm(8,7), imm(5), b("01"))
    cmd("C.LUI", mapTo("LUI"),
        b("011"), imm(17), rd(), imm(16,12), b("01"))
    cmd("C.SRLI", mapTo("SRLI"),
        b("100"), b("0"), b("00"), rsdp(), uimm(4,0), b("01"))
    cmd("C.SRAI", mapTo("SRAI"),
        b("100"), b("0"), b("01"), rsdp(), uimm(4,0), b("01"))
    cmd("C.ANDI", mapTo("ANDI"),
        b("100"), imm(5), b("10"), rsdp(), imm(4,0), b("01"))
    cmd("C.SUB", mapTo("SUB"),
        b("100"), b("0"), b("11"), rsdp(), b("00"), rs2p(), b("01"))
    cmd("C.XOR", mapTo("XOR"),
        b("100"), b("0"), b("11"), rsdp(), b("01"), rs2p(), b("01"))
    cmd("C.OR", mapTo("OR"),
        b("100"), b("0"), b("11"), rsdp(), b("10"), rs2p(), b("01"))
    cmd("C.AND", mapTo("AND"),
        b("100"), b("0"), b("11"), rsdp(), b("11"), rs2p(), b("01"))
    cmd("C.J", mapTo("JAL", [(rd(), 0)]),
        b("101"), imm(11), imm(4), imm(9,8), imm(10), imm(6), imm(7), imm(3,1), imm(5), b("01"))
    cmd("C.BEQZ", mapTo("BEQ", [(rs2(), 0)]),
        b("110"), imm(8), imm(4,3), rs1p(), imm(7,6), imm(2,1), imm(5), b("01"))
    cmd("C.BNEZ", mapTo("BNE", [(rs2(), 0)]),
        b("111"), imm(8), imm(4,3), rs1p(), imm(7,6), imm(2,1), imm(5), b("01"))

    cmd("C.SLLI", mapTo("SLLI"),
        b("000"), b("0"), rsd(), uimm(4,0), b("10"))
    cmd("C.LWSP", mapTo("LW", [(rs1(), 2)]),
        b("010"), uimm(5), rd(), uimm(4,2), uimm(7,6), b("10"))
    cmd("C.JR", mapTo("JALR", [(rd(), 0), (imm(), 0)]),
        b("100"), b("0"), rs1(), b("00000"), b("10"))
    cmd("C.MV", mapTo("ADD", [(rs1(), 0)]),
        b("100"), b("0"), rd(), rs2(), b("10"))
    # C.EBREAK is skipped intentionally to save resources
    cmd("C.JALR", mapTo("JALR", [(rd(), 1), (imm(), 0)]),
        b("100"), b("1"), rs1(), b("00000"), b("10"))
    cmd("C.ADD", mapTo("ADD"),
        b("100"), b("1"), rsd(), rs2(), b("10"))
    cmd("C.SWSP", mapTo("SW", (rs1(), 2)),
        b("110"), uimm(5,2), uimm(7,6), rs2(), b("10"))


def Main():
    DefineCommands16()


if __name__ == "__main__":
    Main()
