// SPDX-License-Identifier: MIT

// Crypto Birds XCB Lottery 1.4
// This smart contract is created by the Community and is not affiliated with Crypto Birds Platform.
// Please visit cryptobirds.com if you are looking for official information.


pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Lottery is ReentrancyGuard {

    address public owner;
    IERC20 public tokenContract;
	
	uint256 public playersTotal;
	uint256 public winnersTotal;
	uint256 public ticketPrice;
	
	address[] private players;
	address[] private winners;
	uint256[] private prizesPercentiles;
	uint256 public lotteryID;
	
	bool public isOpen;
	bool public isCompleted;
	
	event Sent(address _from, address _to, uint256 _amount);
	event NewPlayer(address _player, uint256 _lotteryID);
	event NewWinner(address _winner, uint256 _lotteryID);

	mapping(address => bool) private blackList;

    constructor ( IERC20 _tokenContract ) {
	    owner = msg.sender;
        tokenContract = _tokenContract;
    }
	
    modifier onlyOwner() {
        require(msg.sender == owner, "Error. Caller is not the owner.");
        _;
    }	

	function setNewLottery ( uint256 _playersTotal,	uint256 _winnersTotal, uint256 _ticketPrice, uint256[] memory _prizesPercentiles ) external onlyOwner {
		require(_winnersTotal < _playersTotal, "Error. More winners than players.");
		require(_winnersTotal == _prizesPercentiles.length, "Error. Inconsistency in the prize list.");
		require(_ticketPrice > 0, "Error. Ticket price is zero.");
		
		uint256 _totalPrizes = 0;
        for (uint256 _i = 0; _i < _prizesPercentiles.length; _i++) {
			_totalPrizes += _prizesPercentiles[_i];
		}
		require(_totalPrizes == 100, "Error. Prizes distribution isn't 100%.");
		
		playersTotal = _playersTotal;
		winnersTotal = _winnersTotal;
		ticketPrice = _ticketPrice;
		prizesPercentiles = _prizesPercentiles;
		lotteryID = block.timestamp;
		
		delete players;
		
		isOpen = true;
		isCompleted = false;
	
	}

    function joinGame() external nonReentrant {
		require(isOpen, "Error. Lottery is closed.");
        require(players.length < playersTotal, "Error. Exceed total players.");
		require(!findWallet(msg.sender, players), "Error. You have already participated.");
		require(!blackList[msg.sender], "Error. Address blacklisted.");
        tokenContract.transferFrom(msg.sender, address(this), ticketPrice);
        players.push(msg.sender);
		emit NewPlayer(msg.sender, lotteryID);
		
        if(players.length == playersTotal){
			isOpen = false;
			isCompleted = true;
		}
    }

	function drawWinners() external onlyOwner {
		require(isCompleted, "Error. Number of player not is completed.");
		uint256 _winnerIndex;
        uint256 _count = 0;
		uint256 _nounce = 0;
		
		delete winners;
	   
        while(_count < winnersTotal){
			_winnerIndex = generateRandom(_count, _nounce);
            if (_count == 0) {
				winners.push( players[_winnerIndex] );
                _count++;
				emit NewWinner(players[_winnerIndex], lotteryID);
            } else {
				if (!findWallet(players[_winnerIndex], winners)) {
					winners.push( players[_winnerIndex] );
					_count++;
					emit NewWinner(players[_winnerIndex], lotteryID);
				} else {
					_nounce++;
				}
			}
		}

    }

	function generateRandom(uint256 _index, uint256 _nounce) private view returns(uint256){
		bytes32 _random = keccak256(abi.encodePacked(_index, _nounce, block.number, block.difficulty, block.timestamp));
		uint256 _winnerIndex = uint256(_random) % playersTotal;
		return _winnerIndex;
	}

	function findWallet(address _wallet, address[] memory _toCheck ) private pure returns(bool){
		bool _finded = false;
		for (uint256 _i = 0; _i < _toCheck.length; _i++){
			if (_toCheck[_i] == _wallet){
				_finded = true;
			}
		}
		return _finded;
	}

    function payPrizes() external onlyOwner {
		uint256 _pool = tokenContract.balanceOf(address(this));
		uint256 _prizeAmount;
		require(isCompleted, "Error. Number of player not is completed.");
		require(winners.length == prizesPercentiles.length, "Error. The winners have not been drawn.");
		require(_pool > 0, "Error. Insufficient balance.");
        for (uint256 _i = 0; _i < winners.length; _i++) {
			_prizeAmount = prizesPercentiles[_i] * _pool / 100;
            tokenContract.transfer(winners[_i], _prizeAmount);
			emit Sent(address(this), winners[_i], _prizeAmount);
		}
		isCompleted = false;
    }

    function withdrawContract(uint256 _tokenAmount) external onlyOwner {
        tokenContract.transfer(address(msg.sender), _tokenAmount);
    }
	
    function getTokenBalance() external view returns (uint256) {
        return tokenContract.balanceOf(address(this)); 
    }	

    function getNumberOfPlayers() external view returns (uint256) {
        return players.length; 
    }	

	function getLastWinners() external view returns (address[] memory) {
		return winners;
	}

    function isPlayer(address _wallet) external view returns (bool) {
        return findWallet(_wallet, players ); 
    }

    function isWinner(address _wallet) external view returns (bool) {
        return findWallet(_wallet, winners ); 
    }
	
	function removeBlackList(address _account) external onlyOwner {
		blackList[_account] = false;
	}

	function setBlackList(address _account) external onlyOwner {
		blackList[_account] = true;
	}	

}	
	
