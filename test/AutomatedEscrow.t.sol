// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ✅ Importaciones con alias (buena práctica)
import {Test} from "forge-std/Test.sol";
import {AutomatedEscrow} from "../src/AutomatedEscrow.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// ✅ Mock Token simplificado - hereda directamente de ERC20
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

contract AutomatedEscrowTest is Test {
    AutomatedEscrow public escrow;
    MockERC20 public mockToken;
    
    address public constant PURCHASER = address(0xB0B); 
    address public constant SUPPLIER = address(0x555);  
    address public constant VALIDATOR = address(0xABC); 
    uint256 public constant ESCROW_AMOUNT = 1000e18; // 1000 tokens
    
    // Eventos para testing
    event OrderCreated(uint256 indexed orderId, address purchaser, address supplier, uint256 amount);
    event DeliveryConfirmed(uint256 indexed orderId, address validator);
    event FundsWithdrawn(uint256 indexed orderId, address supplier, uint256 amount);
    
    function setUp() public {
        // 1. Desplegar el Mock Token
        mockToken = new MockERC20("Stablecoin Test", "TUSD");
        
        // 2. Desplegar el contrato de Escrow, pasándole la dirección del token
        escrow = new AutomatedEscrow(address(mockToken));
        
        // 3. Dar tokens al Comprador
        mockToken.mint(PURCHASER, ESCROW_AMOUNT * 10); // Suficiente para múltiples tests
        
        // 4. Etiquetar direcciones para mejor debugging
        vm.label(PURCHASER, "Purchaser");
        vm.label(SUPPLIER, "Supplier");
        vm.label(VALIDATOR, "Validator");
        vm.label(address(escrow), "Escrow");
        vm.label(address(mockToken), "MockToken");
    }
    
    /**
     * @notice Test del flujo completo exitoso
     */
    function test_FullSuccessfulFlow_ERC20() public {
        // 1. PREPARACIÓN: El comprador debe APROBAR el gasto al contrato de Escrow
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        vm.stopPrank();
        
        // Verificar la aprobación
        assertEq(
            mockToken.allowance(PURCHASER, address(escrow)), 
            ESCROW_AMOUNT, 
            "Allowance incorrecta"
        );
        
        // 2. ACCIÓN (Comprador): Crear la orden
        vm.startPrank(PURCHASER);
        vm.expectEmit(true, false, false, true);
        emit OrderCreated(1, PURCHASER, SUPPLIER, ESCROW_AMOUNT);
        uint256 orderId = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
        
        // VERIFICACIÓN 1: El contrato tiene los tokens
        assertEq(
            mockToken.balanceOf(address(escrow)), 
            ESCROW_AMOUNT, 
            "El contrato no tiene los tokens"
        );
        assertEq(orderId, 1, "Order ID deberia ser 1");
        
        // Verificar estado de la orden
        AutomatedEscrow.Order memory order = escrow.getOrder(orderId);
        assertEq(order.purchaser, PURCHASER, "Purchaser incorrecto");
        assertEq(order.supplier, SUPPLIER, "Supplier incorrecto");
        assertEq(order.validator, VALIDATOR, "Validator incorrecto");
        assertEq(order.amount, ESCROW_AMOUNT, "Amount incorrecto");
        assertEq(uint256(order.state), uint256(AutomatedEscrow.State.Pending), "Estado no es Pending");
        
        // 3. ACCIÓN (Validador): Confirmar la entrega
        vm.startPrank(VALIDATOR);
        vm.expectEmit(true, false, false, true);
        emit DeliveryConfirmed(orderId, VALIDATOR);
        escrow.confirmDelivery(orderId);
        vm.stopPrank();
        
        // VERIFICACIÓN 2: El estado cambió a DELIVERED
        order = escrow.getOrder(orderId);
        assertEq(
            uint256(order.state), 
            uint256(AutomatedEscrow.State.Delivered), 
            "El estado no es DELIVERED"
        );
        
        // 4. ACCIÓN (Proveedor): Retirar los fondos
        uint256 initialSupplierBalance = mockToken.balanceOf(SUPPLIER); 
        
        vm.startPrank(SUPPLIER);
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(orderId, SUPPLIER, ESCROW_AMOUNT);
        escrow.withdrawFunds(orderId);
        vm.stopPrank();
        
        // VERIFICACIÓN 3: El contrato está vacío, el proveedor recibió el pago
        assertEq(
            mockToken.balanceOf(address(escrow)), 
            0, 
            "El contrato no deberia tener tokens"
        );
        assertEq(
            mockToken.balanceOf(SUPPLIER), 
            initialSupplierBalance + ESCROW_AMOUNT, 
            "El proveedor no recibio el pago completo"
        );
        
        // Verificar que el amount se puso a 0
        order = escrow.getOrder(orderId);
        assertEq(order.amount, 0, "Amount deberia ser 0 despues del retiro");
    }
    
    /**
     * @notice Test de creación de orden sin aprobación
     */
    function test_CreateOrder_WithoutApproval_Fails() public {
        vm.startPrank(PURCHASER);
        // No se hace approve
        
        // ✅ OpenZeppelin usa errores personalizados, no strings
        // Esperamos que falle con cualquier revert (el error específico es ERC20InsufficientAllowance)
        vm.expectRevert();
        escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
    }
    
    /**
     * @notice Test de confirmación de entrega por persona no autorizada
     */
    function test_ConfirmDelivery_NotValidator_Fails() public {
        // Setup: Crear orden
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 orderId = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
        
        // Intentar confirmar con cuenta no autorizada
        vm.startPrank(SUPPLIER);
        vm.expectRevert("Only the designated validator can confirm delivery");
        escrow.confirmDelivery(orderId);
        vm.stopPrank();
    }
    
    /**
     * @notice Test de retiro de fondos sin confirmación
     */
    function test_WithdrawFunds_WithoutConfirmation_Fails() public {
        // Setup: Crear orden
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 orderId = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
        
        // Intentar retirar sin confirmación
        vm.startPrank(SUPPLIER);
        vm.expectRevert("Funds cannot be withdrawn: Delivery not confirmed");
        escrow.withdrawFunds(orderId);
        vm.stopPrank();
    }
    
    /**
     * @notice Test de cancelación de orden por el comprador
     */
    function test_CancelOrder_Success() public {
        // Setup: Crear orden
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 initialBalance = mockToken.balanceOf(PURCHASER);
        uint256 orderId = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
        
        // Verificar que los tokens se transfirieron
        assertEq(
            mockToken.balanceOf(PURCHASER), 
            initialBalance - ESCROW_AMOUNT, 
            "Tokens no se transfirieron"
        );
        
        // Cancelar orden
        vm.startPrank(PURCHASER);
        escrow.cancelOrder(orderId);
        vm.stopPrank();
        
        // Verificar que los tokens se devolvieron
        assertEq(
            mockToken.balanceOf(PURCHASER), 
            initialBalance, 
            "Tokens no se devolvieron"
        );
        
        // Verificar estado
        AutomatedEscrow.Order memory order = escrow.getOrder(orderId);
        assertEq(
            uint256(order.state), 
            uint256(AutomatedEscrow.State.Canceled), 
            "Estado no es Canceled"
        );
    }
    
    /**
     * @notice Test de doble retiro (debe fallar)
     */
    function test_WithdrawFunds_Twice_Fails() public {
        // Setup: Flujo completo hasta el retiro
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 orderId = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        vm.stopPrank();
        
        vm.prank(VALIDATOR);
        escrow.confirmDelivery(orderId);
        
        vm.prank(SUPPLIER);
        escrow.withdrawFunds(orderId);
        
        // Intentar retirar de nuevo
        vm.startPrank(SUPPLIER);
        vm.expectRevert("Order does not exist or funds already withdrawn");
        escrow.withdrawFunds(orderId);
        vm.stopPrank();
    }
    
    /**
     * @notice Test de creación con cantidad cero
     */
    function test_CreateOrder_ZeroAmount_Fails() public {
        vm.startPrank(PURCHASER);
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        
        vm.expectRevert("Amount must be greater than zero");
        escrow.createOrder(SUPPLIER, VALIDATOR, 0);
        vm.stopPrank();
    }
    
    /**
     * @notice Test de múltiples órdenes
     */
    function test_MultipleOrders_Success() public {
        vm.startPrank(PURCHASER);
        
        // Crear primera orden
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 orderId1 = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        
        // Crear segunda orden
        mockToken.approve(address(escrow), ESCROW_AMOUNT);
        uint256 orderId2 = escrow.createOrder(SUPPLIER, VALIDATOR, ESCROW_AMOUNT);
        
        vm.stopPrank();
        
        assertEq(orderId1, 1, "Primera orden deberia ser 1");
        assertEq(orderId2, 2, "Segunda orden deberia ser 2");
        assertEq(
            mockToken.balanceOf(address(escrow)), 
            ESCROW_AMOUNT * 2, 
            "Contrato deberia tener 2x ESCROW_AMOUNT"
        );
    }
}