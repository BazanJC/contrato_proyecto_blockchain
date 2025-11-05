// script/AutomatedEscrow.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30; 

import "forge-std/Script.sol";
import "src/AutomatedEscrow.sol";

contract AutomatedEscrowScript is Script {
    function run() public returns (AutomatedEscrow) {
        // Reemplaza con una dirección real de token ERC-20 en Base Sepolia
        address TOKEN_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC en Base Sepolia como ejemplo
        
        if (TOKEN_ADDRESS == address(0)) {
            revert("TOKEN_ADDRESS debe ser una direccion valida de un token ERC-20 en Base Sepolia.");
        }

        // Cargar la clave privada de tu entorno
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 1. Iniciar la transmisión de la transacción
        vm.startBroadcast(deployerPrivateKey);

        // 2. Despliegue del contrato: pasamos la dirección del token al constructor
        AutomatedEscrow escrowContract = new AutomatedEscrow(TOKEN_ADDRESS);

        // 3. Finalizar la transmisión
        vm.stopBroadcast();

        console.log("Contrato AutomatedEscrow desplegado en Base Sepolia:");
        console.log(address(escrowContract));
        console.log("Usando token ERC-20 en:", TOKEN_ADDRESS);

        return escrowContract;
    }
}