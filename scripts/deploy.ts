import {
  arrayify,
  formatBytes32String,
  isHexString,
  keccak256,
  toUtf8Bytes,
} from "ethers/lib/utils";

export const ADDRESS_0X0 = "0x0000000000000000000000000000000000000000";

export const convertStringToBytes32 = (str: string): Uint8Array => {
  let bytes32Str: string;
  if (str.length > 31) {
    bytes32Str = keccak256(isHexString(str) ? str : toUtf8Bytes(str));
  } else {
    bytes32Str = formatBytes32String(str);
  }
  return arrayify(bytes32Str);
};

async function getRedstonePayloadForManualUsage() {
  // const provider = new ethers.providers.JsonRpcProvider(
  //   "http://127.0.0.1:8545",
  // );
  // console.error("Hekki");
  // const signer = provider.getSigner(0);
  // // const factory = new RedstonePriceFeed__factory(signer);
  // // const pf = await factory.deploy(
  // //   "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
  // //   convertStringToBytes32("SHIB"),
  // //   [
  // //     "0x0C39486f770B26F5527BBBf942726537986Cd7eb",
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //     ADDRESS_0X0,
  // //   ],
  // //   1,
  // // );
  // // await pf.deployed();
  // // console.log("DEPLOYED: ", pf.address);
  // const pf = RedstonePriceFeed__factory.connect(address, signer);
  // const t = await pf.dataFeedId();
  // console.log("DATA FEED ID: ", t);
}

getRedstonePayloadForManualUsage()
  .then(payload => {
    console.log(`${payload}`);
  })
  .catch(error => {
    console.error(error);
  });
