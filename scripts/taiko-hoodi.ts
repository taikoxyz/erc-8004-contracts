import { defineChain } from "viem";

// Definition for Taiko Hoodi network until viem supports Taiko Hoodi
export const taikoHoodi = defineChain({
    id: 167013,
    name: "Taiko Hoodi",
    network: "taikohoodi",
    nativeCurrency: {
        name: "Ether",
        symbol: "ETH",
        decimals: 18,
    },
    rpcUrls: {
        default: {
            http: ["https://rpc.hoodi.taiko.xyz"]
        },
        public: {
            http: ["https://rpc.hoodi.taiko.xyz"],
        },
    },
    blockExplorers: {
        default: {
            name: "TaikoScan (Hoodi)",
            url: "https://hoodi.taikoscan.io",
        },
    },
    testnet: true,
} as const);
