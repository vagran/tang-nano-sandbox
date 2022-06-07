import argparse
from enum import Enum, auto

args = None

class OpcodeComponent:
    """Bit-field in a command opcode.
    """
    def GetSize():
        """
        :return: Field size in bits
        """
        raise Exception("Method not implemented")


class CommandDesc:
    def __init__(self, name, components, mapTo=None) -> None:
        self.name = name
        self.components = components
        self.mapTo = mapTo

    def VerifyBindings(self, bindings):
        if bindings is None:
            return
        for b in bindings:
            if self.FindParam(b[0]) is None:
                raise Exception(
                    f"Cannot match binding of type {b[0].__class__.__name__} to command {self.name}")

    def GetSize(self):
        size = 0
        for comp in self.components:
            size += comp.GetSize()
        return size

    def FindParam(self, paramType):

        if isinstance(paramType, imm):
            predicate = lambda c: isinstance(c, imm)
        elif isinstance(paramType, RegReference):

            if paramType.regType == RegType.SRC1:
                regList = [RegType.SRC1, RegType.SRC_DST]
            elif paramType.regType == RegType.DST:
                regList = [RegType.DST, RegType.SRC_DST]
            else:
                regList = [paramType.regType]
            predicate = lambda c: isinstance(c, RegReference) and (c.regType in regList)
        else:
            raise Exception(f"Unsupported parameter type: {paramType}")

        return next((c for c in self.components if predicate(c)), None)

# Indexed by command name, element is CommandDesc
commands32 = {}
commands16 = {}

# ##################################################################################################
# Elements for declarative description of commands

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
        self.size = len(bits)
        if self.size > 32:
            raise Exception("Too long field")
        self.value = int(bits, base=2)

    def GetSize(self):
        return self.size


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
        if loBit is not None and loBit > hiBit:
            raise Exception("loBit is greater than hiBit")
        self.hiBit = hiBit
        self.loBit = loBit
        self.isUnsigned = isUnsigned

    def GetSize(self):
        if self.hiBit is None:
            raise Exception("No size for bind target")
        return 1 if self.loBit is None else self.hiBit - self.loBit + 1


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
        self.regType = regType
        self.isCompressed = isCompressed

    def GetSize(self):
        return 3 if self.isCompressed else 5


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
    if name in commands32:
        raise Exception(f"Command {name} already defined")
    cmd = CommandDesc(name, components)
    if cmd.GetSize() != 32:
        raise Exception(f"Command size is not 32 bits: {cmd.GetSize()} for {name}")
    commands32[name] = cmd


def cmd16(name, mapTo, *components):
    if name in commands16:
        raise Exception(f"Command {name} already defined")
    cmd = CommandDesc(name, components)
    if cmd.GetSize() != 16:
        raise Exception(f"Command size is not 16 bits: {cmd.GetSize()} for {name}")
    commands16[name] = cmd


class mapTo:
    def __init__(self, cmdName, bindings=None):
        """Mapping to 32 bits command.
        :param cmdName: 32 bits command name
        :param bindings: list of tuples (field, value)
        """
        if cmdName not in commands32:
            raise Exception(f"Target command {cmdName} not found")
        self.targetCmd = commands32[cmdName]
        self.targetCmd.VerifyBindings(bindings)
        self.bindings = bindings

# ##################################################################################################
# Commands declarative description based on RISC-V Instruction Set Manual

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
    cmd("SUB",
        b("0100000"), rs2(), rs1(), b("000"), rd(), b("0110011"))
    cmd("XOR",
        b("0000000"), rs2(), rs1(), b("100"), rd(), b("0110011"))
    cmd("OR",
        b("0000000"), rs2(), rs1(), b("110"), rd(), b("0110011"))
    cmd("AND",
        b("0000000"), rs2(), rs1(), b("111"), rd(), b("0110011"))


def DefineCommands16():
    cmd = cmd16

    cmd("C.ADDI4SPN", mapTo("ADDI", [(rs1(), 2)]),
        b("000"), uimm(5,4), uimm(9,6), uimm(2), uimm(3), rdp(), b("00"))
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
    cmd("C.SWSP", mapTo("SW", [(rs1(), 2)]),
        b("110"), uimm(5,2), uimm(7,6), rs2(), b("10"))

# ##################################################################################################

class CommandTransform:
    """Implements command transformation from compressed 16-bits representation to 32-bits
    representation.
    """
    def __init__(self) -> None:
        self.components = []



def Main():
    global args

    parser = argparse.ArgumentParser(description="Generate opcodes decompressor and tests")
    parser.add_argument("--doSelfTest", action="store_true")
    parser.add_argument("--compiler", metavar="COMPILER_PATH", type=str,
                        help="Compiler path for self-testing")
    parser.add_argument("--objdump", metavar="OBJDUMP_PATH", type=str,
                        help="objdump path for self-testing")

    args = parser.parse_args()

    DefineCommands32()
    DefineCommands16()


if __name__ == "__main__":
    Main()
