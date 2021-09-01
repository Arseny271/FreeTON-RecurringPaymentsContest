const path = require("path");
const fs = require("fs");
const readline = require('readline');

function loadTerms(name) {
    const termsPath = path.resolve(
        __dirname,
        "..",
        "terms",
        name,
    );

    return JSON.parse(fs.readFileSync(`${termsPath}.json`));
}

function loadTokens(name) {
    const termsPath = path.resolve(
        __dirname,
        "..",
        "tokens",
        name,
    );

    return JSON.parse(fs.readFileSync(`${termsPath}.json`));
}

function loadContract(name) {
    const contractPath = path.resolve(
        __dirname,
        "..",
        "free-ton",
        "build",
        name,
    );
    return {
        abi: {
            type: "Contract",
            value: require(`${contractPath}.abi.json`),
        },
        tvc: fs.readFileSync(`${contractPath}.tvc`).toString("base64"),
    };
}

async function prepareSignerWithRandomKeys(client, keyPairFile) {
    const keyPair = await client.crypto.generate_random_sign_keys();
    fs.writeFileSync(keyPairFile, JSON.stringify(keyPair));

    console.log(`Generated keyPair:`);
    console.log(keyPair);

    return {
        type: "Keys",
        keys: keyPair,
    };
}

async function getPreparedSigner(client, keyPairName) {
    const keyPairFile = path.join(__dirname, `${keyPairName}.json`);

    if (!fs.existsSync(keyPairFile)) {
        await prepareSignerWithRandomKeys(client, keyPairFile);
    }

    const keyPair = JSON.parse(fs.readFileSync(keyPairFile, "utf8"));
    return {
        type: "Keys",
        keys: keyPair,
    };
}

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

String.prototype.hexEncode = function(){
    var hex, i;

    var result = "";
    for (i=0; i<this.length; i++) {
        hex = this.charCodeAt(i).toString(16);
        result += ("000"+hex).slice(-2);
    }

    return result
}

let crcTable = []
var makeCRCTable = function(){
    let c;
    for(let n =0; n < 256; n++){
        c = n;
        for(let k =0; k < 8; k++){
            c = ((c&1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1));
        }
        crcTable[n] = c;
    }
    return crcTable;
}

var crc32 = function(str) {
    var crcTable = crcTable || (crcTable = makeCRCTable());
    var crc = 0 ^ (-1);

    for (var i = 0; i < str.length; i++ ) {
        crc = (crc >>> 8) ^ crcTable[(crc ^ str.charCodeAt(i)) & 0xFF];
    }

    return (crc ^ (-1)) >>> 0;
};

module.exports = {
    loadTokens, crc32, loadTerms, loadContract, prepareSignerWithRandomKeys, getPreparedSigner, rl
};