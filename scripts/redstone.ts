import { DataServiceWrapper } from "@redstone-finance/evm-connector/dist/src/wrappers/DataServiceWrapper";
import { ethers } from "ethers";
import { arrayify } from "ethers/lib/utils";
import { RedstonePayloadParser } from "redstone-protocol/dist/src/redstone-payload/RedstonePayloadParser";

async function getRedstonePayloadForManualUsage(): Promise<string> {
  const dataPayload = await new DataServiceWrapper({
    dataServiceId: "redstone-main-demo",
    dataFeeds: ["SHIB"],
    uniqueSignersCount: 1,
  }).prepareRedstonePayload(true);

  const parser = new RedstonePayloadParser(arrayify(`0x${dataPayload}`));
  const { signedDataPackages } = parser.parse();

  let dataPackageIndex = 0;
  let ts = 0;
  for (const signedDataPackage of signedDataPackages) {
    const newTimestamp =
      signedDataPackage.dataPackage.timestampMilliseconds / 1000;
    console.error(`Data package: ${dataPackageIndex}`);
    console.error(`Timestamp: ${newTimestamp}`);

    if (dataPackageIndex === 0) {
      ts = newTimestamp;
    } else if (ts !== newTimestamp) {
      throw new Error("Timestamps are not equal");
    }

    ++dataPackageIndex;
  }

  const result = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "bytes"],
    [ts, arrayify(`0x${dataPayload}`)],
  );

  return result;
}

getRedstonePayloadForManualUsage()
  .then(payload => {
    console.log(`${payload}`);
  })
  .catch(error => {
    console.error(error);
  });
