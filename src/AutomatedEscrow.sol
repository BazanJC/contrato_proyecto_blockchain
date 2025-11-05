// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ruta del contrato ERC-20
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AutomatedEscrow {
    enum State { Pending, Delivered, Canceled }
    
    struct Order {
        address purchaser;       
        address supplier;        
        address validator;       
        uint256 amount;          
        State state;
    }
    
    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId = 1;
    
    // Contrato del token ERC-20 a usar
    IERC20 public immutable token; 
    
    // Eventos
    event OrderCreated(uint256 indexed orderId, address purchaser, address supplier, uint256 amount);
    event DeliveryConfirmed(uint256 indexed orderId, address validator);
    event FundsWithdrawn(uint256 indexed orderId, address supplier, uint256 amount);
    event OrderCanceled(uint256 indexed orderId);
    
    /**
     * @notice Constructor que establece la dirección del token.
     * @param _tokenAddress Dirección del contrato ERC20 a utilizar
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);
    }
    
    /**
     * @notice Crea una nueva orden de escrow. Requiere que el Comprador apruebe el token previamente.
     * @param _supplier Dirección del proveedor
     * @param _validator Dirección del validador
     * @param _amount Cantidad de tokens a depositar
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
        
        // El contrato extrae los tokens del comprador
        // Requiere: token.approve(escrowAddress, amount) previo
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer from purchaser failed (Did you approve?)");
        
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
     * @notice Confirma la entrega. Solo el validador puede llamar.
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
     * @notice Permite al proveedor retirar los fondos (tokens) si la entrega ha sido confirmada.
     * @param _orderId ID de la orden para retirar fondos
     */
    function withdrawFunds(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.amount > 0, "Order does not exist or funds already withdrawn");
        require(msg.sender == order.supplier, "Only the supplier can withdraw funds");
        require(order.state == State.Delivered, "Funds cannot be withdrawn: Delivery not confirmed");
        
        uint256 paymentAmount = order.amount;
        
        // Evita doble retiro (checks-effects-interactions pattern)
        order.amount = 0; 
        order.state = State.Canceled; // Marca como finalizada
        
        // El contrato transfiere los tokens al proveedor
        bool success = token.transfer(order.supplier, paymentAmount);
        require(success, "Token transfer to supplier failed");
        
        emit FundsWithdrawn(_orderId, msg.sender, paymentAmount);
    }
    
    /**
     * @notice Permite al comprador cancelar la orden y recuperar fondos si aún está pendiente
     * @param _orderId ID de la orden a cancelar
     */
    function cancelOrder(uint256 _orderId) public {
        Order storage order = orders[_orderId];
        require(order.amount > 0, "Order does not exist or funds already withdrawn");
        require(msg.sender == order.purchaser, "Only the purchaser can cancel");
        require(order.state == State.Pending, "Order can only be canceled if Pending");
        
        uint256 refundAmount = order.amount;
        
        // Evita doble retiro
        order.amount = 0;
        order.state = State.Canceled;
        
        // Devuelve los tokens al comprador
        bool success = token.transfer(order.purchaser, refundAmount);
        require(success, "Token refund failed");
        
        emit OrderCanceled(_orderId);
    }
    
    /**
     * @notice Obtiene los detalles de una orden
     * @param _orderId ID de la orden
     * @return Order struct con todos los detalles
     */
    function getOrder(uint256 _orderId) public view returns (Order memory) {
        return orders[_orderId];
    }
}