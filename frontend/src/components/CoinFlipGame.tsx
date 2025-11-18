'use client';

import React, { useState } from 'react';
import { useAccount } from 'wagmi';

type CoinSide = 'heads' | 'tails';
type GameState = 'idle' | 'betting' | 'flipping' | 'result';

interface BetResult {
  won: boolean;
  side: CoinSide;
  amount: string;
  payout: string;
  randomWord: string;
}

const CoinFlipGame: React.FC = () => {
  const { isConnected } = useAccount();
  const [gameState, setGameState] = useState<GameState>('idle');
  const [selectedSide, setSelectedSide] = useState<CoinSide>('heads');
  const [betAmount, setBetAmount] = useState('100');
  const [gameTokenBalance, setGameTokenBalance] = useState('0');
  const [hasPass, setHasPass] = useState(false);
  const [lastResult, setLastResult] = useState<BetResult | null>(null);
  const [coinSide, setCoinSide] = useState<CoinSide>('heads');

  // Mock data - in real app, these would come from contract calls
  const minBet = 10;
  const maxBet = 1000;

  const handlePlaceBet = async () => {
    if (!isConnected || !hasPass) return;
    
    const amount = parseFloat(betAmount);
    if (amount < minBet || amount > maxBet) {
      alert(`Bet amount must be between ${minBet} and ${maxBet} GAME`);
      return;
    }

    setGameState('betting');
    
    try {
      // Simulate contract interaction
      console.log(`Placing bet: ${amount} GAME on ${selectedSide}`);
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setGameState('flipping');
      
      // Simulate VRF delay and coin flip
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      // Simulate random result
      const randomResult: CoinSide = Math.random() > 0.5 ? 'heads' : 'tails';
      const won = randomResult === selectedSide;
      const payout = won ? (amount * 2 * 0.98).toString() : '0'; // 2% house edge
      
      setCoinSide(randomResult);
      setLastResult({
        won,
        side: randomResult,
        amount: amount.toString(),
        payout,
        randomWord: '0x' + Math.random().toString(16).slice(2, 18)
      });
      
      setGameState('result');
      
      // Reset after showing result
      setTimeout(() => {
        setGameState('idle');
      }, 5000);
      
    } catch (error) {
      console.error('Bet failed:', error);
      alert('Bet failed. Please try again.');
      setGameState('idle');
    }
  };

  const resetGame = () => {
    setGameState('idle');
    setLastResult(null);
  };

  if (!hasPass) {
    return (
      <div className="card text-center max-w-md mx-auto">
        <div className="text-4xl mb-4">🎫</div>
        <h4 className="text-xl font-semibold mb-2">NFT Pass Required</h4>
        <p className="text-gray-400 mb-4">
          You need an NFT pass to play games. Mint one to get started!
        </p>
        <button 
          className="btn-primary"
          onClick={() => document.getElementById('passes')?.scrollIntoView({ behavior: 'smooth' })}
        >
          Get NFT Pass
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Game Interface */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Betting Panel */}
        <div className="card">
          <h4 className="text-xl font-semibold mb-4">Place Your Bet</h4>
          
          {/* Side Selection */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-400 mb-3">
              Choose Side
            </label>
            <div className="grid grid-cols-2 gap-3">
              <button
                className={`p-4 rounded-lg border-2 transition-all duration-200 ${
                  selectedSide === 'heads'
                    ? 'border-blue-500 bg-blue-600 bg-opacity-20'
                    : 'border-gray-600 hover:border-gray-500'
                }`}
                onClick={() => setSelectedSide('heads')}
                disabled={gameState !== 'idle'}
              >
                <div className="text-3xl mb-2">👑</div>
                <div className="font-semibold">Heads</div>
              </button>
              <button
                className={`p-4 rounded-lg border-2 transition-all duration-200 ${
                  selectedSide === 'tails'
                    ? 'border-blue-500 bg-blue-600 bg-opacity-20'
                    : 'border-gray-600 hover:border-gray-500'
                }`}
                onClick={() => setSelectedSide('tails')}
                disabled={gameState !== 'idle'}
              >
                <div className="text-3xl mb-2">🦅</div>
                <div className="font-semibold">Tails</div>
              </button>
            </div>
          </div>

          {/* Bet Amount */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-400 mb-3">
              Bet Amount (GAME)
            </label>
            <div className="space-y-3">
              <input
                type="number"
                value={betAmount}
                onChange={(e) => setBetAmount(e.target.value)}
                className="input-primary w-full"
                placeholder={`Min: ${minBet}, Max: ${maxBet}`}
                min={minBet}
                max={maxBet}
                disabled={gameState !== 'idle'}
              />
              <div className="flex space-x-2">
                {[25, 50, 100, 250].map((amount) => (
                  <button
                    key={amount}
                    className="btn-secondary text-xs px-3 py-1"
                    onClick={() => setBetAmount(amount.toString())}
                    disabled={gameState !== 'idle'}
                  >
                    {amount}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Balance & Limits */}
          <div className="mb-6 p-3 bg-gray-700 rounded-lg">
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-400">GAME Balance:</span>
              <span className="font-semibold">{gameTokenBalance}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-400">Potential Win:</span>
              <span className="font-semibold text-green-400">
                {(parseFloat(betAmount || '0') * 1.96).toFixed(2)} GAME
              </span>
            </div>
          </div>

          {/* Place Bet Button */}
          <button
            className={`w-full py-3 text-lg font-semibold transition-all duration-200 ${
              gameState === 'idle' 
                ? 'btn-primary' 
                : gameState === 'betting'
                  ? 'btn-warning'
                  : gameState === 'flipping'
                    ? 'btn-secondary'
                    : 'btn-success'
            }`}
            onClick={handlePlaceBet}
            disabled={gameState !== 'idle'}
          >
            {gameState === 'idle' && `Bet ${betAmount} GAME on ${selectedSide.toUpperCase()}`}
            {gameState === 'betting' && (
              <div className="flex items-center justify-center space-x-2">
                <div className="loading-spinner w-5 h-5"></div>
                <span>Placing Bet...</span>
              </div>
            )}
            {gameState === 'flipping' && (
              <div className="flex items-center justify-center space-x-2">
                <div className="loading-spinner w-5 h-5"></div>
                <span>Flipping Coin...</span>
              </div>
            )}
            {gameState === 'result' && 'Result Ready!'}
          </button>
        </div>

        {/* Coin Visualization */}
        <div className="card">
          <h4 className="text-xl font-semibold mb-4">Coin Flip</h4>
          
          <div className="flex flex-col items-center justify-center py-8">
            <div className={`relative w-32 h-32 mb-6 ${
              gameState === 'flipping' ? 'coin-flip' : ''
            }`}>
              <div className="absolute inset-0 bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-full flex items-center justify-center text-4xl shadow-lg">
                {gameState === 'result' && lastResult ? (
                  lastResult.side === 'heads' ? '👑' : '🦅'
                ) : (
                  coinSide === 'heads' ? '👑' : '🦅'
                )}
              </div>
              {gameState === 'flipping' && (
                <div className="absolute inset-0 rounded-full border-4 border-blue-500 animate-pulse"></div>
              )}
            </div>

            <div className="text-center">
              {gameState === 'idle' && (
                <p className="text-gray-400">Ready to flip!</p>
              )}
              {gameState === 'betting' && (
                <p className="text-yellow-400">Placing your bet...</p>
              )}
              {gameState === 'flipping' && (
                <div>
                  <p className="text-blue-400 font-semibold mb-2">Coin is flipping...</p>
                  <p className="text-sm text-gray-400">Waiting for Chainlink VRF</p>
                </div>
              )}
              {gameState === 'result' && lastResult && (
                <div className="space-y-2">
                  <p className={`text-xl font-bold ${
                    lastResult.won ? 'text-green-400' : 'text-red-400'
                  }`}>
                    {lastResult.won ? '🎉 You Won!' : '😔 You Lost'}
                  </p>
                  <p className="text-gray-400">
                    Result: {lastResult.side.toUpperCase()}
                  </p>
                  {lastResult.won && (
                    <p className="text-green-400 font-semibold">
                      Payout: {lastResult.payout} GAME
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>

          {gameState === 'result' && (
            <button
              className="btn-primary w-full"
              onClick={resetGame}
            >
              Play Again
            </button>
          )}
        </div>
      </div>

      {/* Game Result Details */}
      {lastResult && gameState === 'result' && (
        <div className="card">
          <h4 className="text-lg font-semibold mb-4">Game Result</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-400">Your Choice:</span>
                <span className="font-semibold">{selectedSide.toUpperCase()}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Actual Result:</span>
                <span className="font-semibold">{lastResult.side.toUpperCase()}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Bet Amount:</span>
                <span className="font-semibold">{lastResult.amount} GAME</span>
              </div>
            </div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-400">Outcome:</span>
                <span className={`font-semibold ${
                  lastResult.won ? 'text-green-400' : 'text-red-400'
                }`}>
                  {lastResult.won ? 'WIN' : 'LOSS'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Payout:</span>
                <span className="font-semibold">{lastResult.payout} GAME</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Random Word:</span>
                <span className="font-mono text-xs text-blue-400">
                  {lastResult.randomWord}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Quick Access Buttons */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <button className="btn-secondary py-3">
          <div className="text-xl mb-1">💰</div>
          <div>Get Test Tokens</div>
        </button>
        
        <button className="btn-secondary py-3">
          <div className="text-xl mb-1">📊</div>
          <div>View History</div>
        </button>
        
        <button className="btn-secondary py-3">
          <div className="text-xl mb-1">🎯</div>
          <div>Game Rules</div>
        </button>
      </div>
    </div>
  );
};

export default CoinFlipGame;