npx hardhat run ./scripts/00-deployAccount.ts
echo "00 ....................................................."
npx hardhat run ./scripts/01-deployRegistry.ts
echo "01 ....................................................."
npx hardhat run ./scripts/02-deployProfile.ts
echo "02 ....................................................."
npx hardhat run ./scripts/03-updateConstants.ts
echo "03 ....................................................."
npx hardhat run ./scripts/10-deployContactList.ts
echo "10 ....................................................."
npx hardhat run ./scripts/11-updateConstants.ts
echo "11 ....................................................."
npx hardhat run ./scripts/20-deployTLCC.ts
echo "20 ....................................................."
npx hardhat run ./scripts/99-updateApiAndWeb.ts
echo "99 ....................................................."

echo "THE END."