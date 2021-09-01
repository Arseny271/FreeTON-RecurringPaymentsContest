const dirTree = require("directory-tree");
const { execSync } = require('child_process');

function flatDirTree(tree) {
  return tree.children.reduce((acc, current) => {
    if (current.children === undefined) {
      return [
        ...acc,
        current,
      ];
    }

    const flatChild = flatDirTree(current);

    return [...acc, ...flatChild];
  }, []);
}

const contractsNestedTree = dirTree(
  "../free-ton/contracts",
  { extensions: /\.sol/ }
);
const contractsTree = flatDirTree(contractsNestedTree);

try {
  contractsTree.map(({ path }) => {
    const [,contractFileName] = path.match(new RegExp('contracts/(.*).sol'));
    const output = execSync(`cd ../free-ton/build && tondev sol compile  ./../contracts/${contractFileName}.sol`);
    console.log(`Compile ${path}`);  
  });
} catch (e) {
}

console.log(`\nCompiling ${contractsTree.length} sources\n`);
