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

        self.immIsSigned = None
        self.immHiBit = None
        curPos = self.GetSize() - 1
        for c in components:
            c.position = curPos
            curPos -= c.GetSize()
            if isinstance(c, ImmediateBits):
                if self.immIsSigned is None:
                    self.immIsSigned = c.isSigned
                elif self.immIsSigned != c.isSigned:
                    raise Exception(f"Mixing signed and unsigned immediate field in one command: {name}")
                if self.immHiBit is None or self.immHiBit < c.hiBit:
                    self.immHiBit = c.hiBit

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

    def FindImmediate(self, immBit):
        """
        :param immBit: Immediate bit index to find.
        :return: Immediate chunk reference with the specified bit if found, None if not found.
        """
        for c in self.components:
            if not isinstance(c, ImmediateBits):
                continue
            if immBit <= c.hiBit and immBit >= c.loBit:
                return c
        return None

# Indexed by command name, element is CommandDesc
commands32 = {}
commands16 = {}

# ##################################################################################################
# Elements for declarative description of commands

class ConstantBits(OpcodeComponent):
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

    @staticmethod
    def FromInt(size, value):
        max = (1 << size) - 1
        if value > max or value < -(max + 1) / 2:
            raise Exception(f"Value out of range: {value}")
        if value < 0:
            value = max + 1 + value
        return ConstantBits(format(value, f"0{size}b"))

    def GetSize(self):
        return self.size

    def Slice(self, hiBit, loBit):
        """Get subset of this bits chunk.
        :param hiBit: High-order bit of the slice.
        :param loBit: Low-order bit of the slice.
        :return: _description_
        """
        if hiBit > self.size - 1:
            raise Exception(f"hiBit out of range: {hiBit}")
        if loBit > hiBit:
            raise Exception(f"loBit is greater than hiBit: {loBit}")
        return ConstantBits(format(self.value, f"0{self.size}b") \
            [self.size - 1 - hiBit : self.size - loBit])


b = ConstantBits

class ImmediateBits(OpcodeComponent):
    """
    Some chunk of immediate value.
    """
    def __init__(self, hiBit=None, loBit=None, isSigned=True):
        """
        :param hiBit: Index of high-ordered bit of the chunk. Can be None when used as bind target.
        :param loBit: Index of low-ordered bit of the chunk, None if one bit chunk.
        """
        super().__init__()
        if loBit is not None and loBit > hiBit:
            raise Exception("loBit is greater than hiBit")
        self.hiBit = hiBit
        self.loBit = loBit
        self.isSigned = isSigned

    def GetSize(self):
        if self.hiBit is None:
            raise Exception("No size for bind target")
        return 1 if self.loBit is None else self.hiBit - self.loBit + 1

imm = ImmediateBits

def uimm(hiBit, loBit=None):
    """
    Chunk of unsigned immediate value.
    """
    return imm(hiBit, loBit, False)


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

# rs1' (prime) - compressed representation
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
    cmd = CommandDesc(name, components, mapTo)
    if cmd.GetSize() != 16:
        raise Exception(f"Command size is not 16 bits: {cmd.GetSize()} for {name}")
    commands16[name] = cmd


class DecompressionMapping:
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

    def FindBinding(self, component):
        """
        :param component: Immediate or register reference.
        :return Binding value, None if not found.
        """
        if isinstance(component, ImmediateBits):
            predicate = lambda ref: isinstance(ref, ImmediateBits)
        elif isinstance(component, RegReference):
            predicate = lambda ref: isinstance(ref, RegReference) and ref.regType == component.regType
        else:
            raise Exception("Unsupported reference type")
        return next((b[1] for b in self.bindings if predicate(b[0])), None)

mapTo = DecompressionMapping

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

class BitsCopy:
    def __init__(self, srcHi, srcLo, numReplicate=None) -> None:
        """Bits chunk copying operation.
        :param srcHi: Index of source high-ordered bit.
        :param srcLo: Index of source low-ordered bit. May be None to indicate one bit size.
        :numReplicate: Source bit (source must be one bit size) is replicated so many times if
        specified (used for sign extension).
        """
        self.srcHi = srcHi
        if srcLo is None:
            self.srcLo = srcHi
        else:
            if srcLo > srcHi:
                raise Exception("srcLo is greater than srcHi")
            self.srcLo = srcLo
        if numReplicate is not None:
            if self.srcLo != self.srcHi:
                raise Exception("Replication count can be specified for 1-bit source only")
        self.numReplicate = numReplicate


class CommandTransform:
    """Implements command transformation from compressed 16-bits representation to 32-bits
    representation.
    """
    def __init__(self, cmd16Desc) -> None:
        self.srcCmd = cmd16Desc
        self.components = []
        targetCmd = cmd16Desc.mapTo.targetCmd
        for c in targetCmd.components:
            if isinstance(c, ConstantBits):
                self.components.append(c)

            elif isinstance(c, RegReference):
                binding = cmd16Desc.mapTo.FindBinding(c)
                if binding is not None:
                    self.components.append(ConstantBits.FromInt(5, binding))
                else:
                    regRef = cmd16Desc.FindParam(c)
                    if regRef is None:
                        raise Exception("Cannot find register in source " +
                                        f"command: {c.regType} in {cmd16Desc.name}")
                    if regRef.isCompressed:
                        # Register field in target is always 5 bits
                        self.components.append(ConstantBits("01"))
                        self.components.append(BitsCopy(regRef.position, regRef.position - 2))
                    else:
                        self.components.append(BitsCopy(regRef.position, regRef.position - 4))

            elif isinstance(c, ImmediateBits):
                binding = cmd16Desc.mapTo.FindBinding(c)
                if binding is not None:
                    bits = ConstantBits.FromInt(targetCmd.immHiBit + 1, binding)
                    self.components.append(bits.Slice(c.hiBit, c.loBit))
                else:
                    self._HandleImmediateChunk(c)

            else:
                raise Exception(f"Unhandled component type {c}")

    def _HandleImmediateChunk(self, c):
        if self.srcCmd.immHiBit is None:
            raise Exception("No immediate field in source command")

        isZeroBits = None
        hiBit = None
        loBit = None
        srcHiBit = None

        def CommitBits():
            nonlocal isZeroBits, hiBit, loBit, srcHiBit

            if isZeroBits is None:
                return
            if isZeroBits:
                self.components.append(ConstantBits.FromInt(hiBit - loBit + 1, 0))
            else:
                self.components.append(BitsCopy(srcHiBit, srcHiBit - (hiBit - loBit)))
            isZeroBits = None
            hiBit = None
            loBit = None
            srcHiBit = None

        def CopyBit(immBit):
            nonlocal isZeroBits, hiBit, loBit, srcHiBit

            srcImm = self.srcCmd.FindImmediate(immBit)
            if isZeroBits is not None and isZeroBits != srcImm is None:
                CommitBits()
            if isZeroBits is None:
                if srcImm is None:
                    isZeroBits = True
                else:
                    isZeroBits = False
                    srcHiBit = srcImm.position - (srcImm.hiBit - immBit)
                hiBit = immBit
            loBit = immBit

        if c.hiBit > self.srcCmd.immHiBit:
            # Handle sign bits
            loSignBit = max(c.loBit, self.srcCmd.immHiBit + 1)
            if self.srcCmd.immIsSigned:
                # Sign extension, find chunk with sign bit in source command
                srcImm = self.srcCmd.FindImmediate(self.srcCmd.immHiBit)
                if srcImm is None:
                    raise Exception("Sign bit not found")
                self.components.append(BitsCopy(srcImm.position, None, c.hiBit - loSignBit + 1))
            else:
                # Leading zeros
                self.components.append(ConstantBits.FromInt(c.hiBit - loSignBit + 1, 0))
            # Handle rest bits of chunk if any
            for immBit in range(loSignBit - 1, c.lowBit - 1, -1):
                CopyBit(immBit)
        else:
            # Just copy all bits (missing ones are set to zero)
            for immBit in range(c.hiBit, c.lowBit - 1, -1):
                CopyBit(immBit)

        CommitBits()

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
