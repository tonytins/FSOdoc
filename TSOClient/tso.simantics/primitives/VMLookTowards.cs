using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using FSO.SimAntics.Engine;
using FSO.Files.Utils;
using FSO.LotView.Model;
using FSO.Files.Formats.IFF.Chunks;
using System.IO;

namespace FSO.SimAntics.Primitives
{
    /// <summary>
    /// This primitive allows the Sim to look at objects or other people, for example during conversations or interactions.
    /// </summary>
    public class VMLookTowards : VMPrimitiveHandler
    {
        /// <summary>
        /// Executes the VMLookTowards primitive.
        /// </summary>
        /// <param name="context">The current VMStackFrame context.</param>
        /// <param name="args">The VMPrimitiveOperand argument containing the operand data.</param>
        /// <returns>The VMPrimitiveExitCode indicating the result of the primitive execution.</returns>
        public override VMPrimitiveExitCode Execute(VMStackFrame context, VMPrimitiveOperand args)
        {
            var operand = (VMLookTowardsOperand)args;
            // TODO: primitive fails if object calls it
            VMAvatar sim = (VMAvatar)context.Caller;

            var result = new VMFindLocationResult();
            result.Position = new LotTilePos(sim.Position);

            LotTilePos pos = new LotTilePos();
            switch (operand.Mode)
            {
                case VMLookTowardsMode.HeadTowardsObject:
                    return VMPrimitiveExitCode.GOTO_TRUE; // TODO: turning head towards things, with head seek timeout
                case VMLookTowardsMode.BodyTowardsCamera:
                    return VMPrimitiveExitCode.GOTO_TRUE; // does not work in TSO
                case VMLookTowardsMode.BodyTowardsStackObj:
                    result.RadianDirection = (float)GetDirectionTo(sim.Position, context.StackObject.Position);
                    break;
                case VMLookTowardsMode.BodyAwayFromStackObj:
                    result.RadianDirection = (float)GetDirectionTo(sim.Position, context.StackObject.Position);
                    result.RadianDirection = (float)((result.RadianDirection + Math.PI) % (Math.PI * 2));
                    break;
                case VMLookTowardsMode.BodyTowardsAverageStackObj:
                    foreach (var obj in context.StackObject.MultitileGroup.Objects)
                        pos += obj.Position;
                    pos /= context.StackObject.MultitileGroup.Objects.Count;
                    result.RadianDirection = (float)GetDirectionTo(sim.Position, pos);
                    break;
                case VMLookTowardsMode.BodyAwayFromAverageStackObj:
                    foreach (var obj in context.StackObject.MultitileGroup.Objects)
                        pos += obj.Position;
                    pos /= context.StackObject.MultitileGroup.Objects.Count;
                    result.RadianDirection = (float)GetDirectionTo(sim.Position, pos);
                    result.RadianDirection = (float)((result.RadianDirection + Math.PI) % (Math.PI * 2));
                    break;
            }

            if (context.Thread.IsCheck) return VMPrimitiveExitCode.GOTO_FALSE;
            var pathFinder = context.Thread.PushNewRoutingFrame(context, false); // use the path finder to do the turn animation.
            pathFinder.InitRoutes(new List<VMFindLocationResult>() { result });

            return VMPrimitiveExitCode.CONTINUE;
        }

        /// <summary>
        /// Calculates the direction in radians from one LotTilePos to another.
        /// </summary>
        /// <param name="pos1">The starting LotTilePos.</param>
        /// <param name="pos2">The target LotTilePos.</param>
        /// <returns>The direction in radians from pos1 to pos2.</returns>
        private double GetDirectionTo(LotTilePos pos1, LotTilePos pos2)
        {
            return Math.Atan2(pos2.x - pos1.x, -(pos2.y - pos1.y));
        }

        /// <summary>
        /// Converts a radian angle to corresponding <see cref="SLOTFlags"/> for routing.
        /// </summary>
        /// <param name="rad">The radian angle to convert.</param>
        /// <returns>The corresponding <see cref="SLOTFlags"/> for the given radian angle.</returns>
        private SLOTFlags RadianToFlags(double rad)
        {
            int result = (int)(Math.Round((rad / (Math.PI * 2)) * 8) + 80) % 8; //for best results, make sure rad is >-pi and <pi
            return (SLOTFlags)(1 << result);
        }
    }

    /// <summary>
    /// Operand for the <see cref="VMLookTowards"/> primitive, specifying the mode of looking towards an object or direction.
    /// </summary>
    public class VMLookTowardsOperand : VMPrimitiveOperand
    {
        /// <summary>
        /// Gets or sets the mode of looking towards an object or direction.
        /// </summary>
        public VMLookTowardsMode Mode { get; set; }

        #region VMPrimitiveOperand Members

        /// <summary>
        /// Reads the operand from a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to read from.</param>
        public void Read(byte[] bytes)
        {
            using (var io = IoBuffer.FromBytes(bytes, ByteOrder.LITTLE_ENDIAN))
            {
                Mode = (VMLookTowardsMode)io.ReadByte();
            }
        }

        /// <summary>
        /// Writes the operand to a byte array.
        /// </summary>
        /// <param name="bytes">The byte array to write to.</param>
        public void Write(byte[] bytes)
        {
            using (var io = new BinaryWriter(new MemoryStream(bytes)))
            {
                io.Write((byte)Mode);
            }
        }

        #endregion
    }

    /// <summary>
    /// Enumerates the modes of looking towards an object or direction for the <see cref="VMLookTowards"/> primitive.
    /// </summary>
    public enum VMLookTowardsMode : byte
    {
        HeadTowardsObject = 0,
        BodyTowardsCamera = 1,
        BodyTowardsStackObj = 2,
        BodyAwayFromStackObj = 3,
        BodyTowardsAverageStackObj = 4,
        BodyAwayFromAverageStackObj = 5
    }
}
