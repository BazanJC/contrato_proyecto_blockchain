// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title AutomatedEscrow
 * @author Tu Nombre
 * @notice Contrato de escrow automatizado para transacciones con tokens ERC20
 * @dev Implementa un sistema de escrow con tres roles: Comprador, Proveedor y Validador
 */
contract AutomatedEscrow {
    // Estados posibles de una orden
    enum State { Pending, Delivered, Canceled }
    
    // Estructura de una orden de escrow
    struct Order {
        address purchaser;       // Dirección del comprador
        address supplier;        // Dirección del proveedor
        address validator;       // Dirección del validador
        uint256 amount;          // Cantidad de tokens en escrow
        State state;            // Estado actual de la orden
    }
    
    // Mapeo de ID de orden a estructura Order
    mapping(uint256 => Order) public orders;
    
    // Contador para IDs de órdenes
    uint256 public nextOrderId = 1;
    
    // Token ERC20 utilizado para las transacciones 
    IERC20 public immutable TOKEN;
    
    // Eventos
    event OrderCreated(uint256 indexed orderId, address purchaser, address supplier, uint256 amount);
    event DeliveryConfirmed(uint256 indexed orderId, address validator);
    event FundsWithdrawn(uint256 indexed orderId, address supplier, uint256 amount);
    event OrderCanceled(uint256 indexed orderId);
    
    /**
     * @notice Constructor que establece la dirección del token ERC20
     * @param _tokenAddress Dirección del contrato ERC20 a utilizar
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        TOKEN = IERC20(_tokenAddress);
    }
    
    /**
     * @notice Crea una nueva orden de escrow
     * @dev Requiere que el comprador haya aprobado previamente el gasto de tokens al contrato
     * @param _supplier Dirección del proveedor que recibirá los fondos
     * @param _validator Dirección del validador que confirmará la entrega
     * @param _amount Cantidad de tokens a depositar en escrow
     * @return orderId ID de la orden creada
     */
    function createOrder(
        address _supplier,
        address _validator,
        uint256 _amount
    ) public returns (uint256) {
        require(_amount > 0, "Amount must be greater than zero");
        require(_supplier != address(0), "Invalid supplier address");
        require(_validator != address(0), "Invalid validator address");
        require(_supplier != msg.sender, "Supplier cannot be the purchaser");
        require(_validator != msg.sender, "Validator cannot be the purchaser");

        TOKEN.transferFrom(msg.sender, address(this), _amount);
        
        uint256 orderId = nextOrderId++;
        
        orders[orderId] = Order({
            purchaser: msg.sender,
            supplier: _supplier,
            validator: _validator,
            amount: _amount,
            state: State.Pending
        });
        
        emit OrderCreated(orderId, msg.sender, _supplier, _amount);
        return orderId;
    }
    
    /**
     * @notice Confirma la entrega de una orden
     * @dev Solo puede ser llamado por el validador designado
     * @param _orderId ID de la orden a confirmar
     */
    function confirmDelivery(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.amount > 0, "Order does not exist");
        require(order.state == State.Pending, "Order state must be Pending");
        require(msg.sender == order.validator, "Only the designated validator can confirm delivery");
        
        order.state = State.Delivered;
        emit DeliveryConfirmed(_orderId, msg.sender);
    }
    
    /**
     * @notice Permite al proveedor retirar los fondos después de la confirmación
     * @dev Solo puede ser llamado por el proveedor y después de la confirmación de entrega
     * @param _orderId ID de la orden para retirar fondos
     */
    function withdrawFunds(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.amount > 0, "Order does not exist or funds already withdrawn");
        require(msg.sender == order.supplier, "Only the supplier can withdraw funds");
        require(order.state == State.Delivered, "Funds cannot be withdrawn: Delivery not confirmed");
        
        uint256 paymentAmount = order.amount;
        
        // Evitar doble retiro (checks-effects-interactions pattern)
        order.amount = 0; 
        order.state = State.Canceled;
        
        // Transferir tokens al proveedor
        // Nota: transfer revierte automáticamente si falla (OpenZeppelin)
        TOKEN.transfer(order.supplier, paymentAmount);
        
        emit FundsWithdrawn(_orderId, msg.sender, paymentAmount);
    }
    
    /**
     * @notice Permite al comprador cancelar la orden y recuperar sus fondos
     * @dev Solo puede ser llamado por el comprador y si la orden está pendiente
     * @param _orderId ID de la orden a cancelar
     */
    function cancelOrder(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.amount > 0, "Order does not exist or funds already withdrawn");
        require(msg.sender == order.purchaser, "Only the purchaser can cancel");
        require(order.state == State.Pending, "Order can only be canceled if Pending");
        
        uint256 refundAmount = order.amount;
        
        // Evitar doble retiro
        order.amount = 0;
        order.state = State.Canceled;
        
        // Devolver tokens al comprador
        // Nota: transfer revierte automáticamente si falla (OpenZeppelin)
        TOKEN.transfer(order.purchaser, refundAmount);
        
        emit OrderCanceled(_orderId);
    }
    
    /**
     * @notice Obtiene los detalles completos de una orden
     * @param _orderId ID de la orden a consultar
     * @return Order Estructura completa con todos los detalles de la orden
     */
    function getOrder(uint256 _orderId) public view returns (Order memory) {
        return orders[_orderId];
    }
}