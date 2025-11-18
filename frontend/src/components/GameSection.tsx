'use client';

import React, { useState } from 'react';
import { useAccount } from 'wagmi';
import CoinFlipGame from './CoinFlipGame';

const GameSection: React.FC = () => {
  const { isConnected } = useAccount();
  const [selectedGame, setSelectedGame] = useState<'coinflip' | null>('coinflip');

  const games = [
    {
      id: 'coinflip' as const,
      name: 'CoinFlip',
      description: 'Bet on heads or tails in this classic probability game',
      icon: '🪙',
      status: 'live' as const,
      minBet: '10 GAME',
      maxBet: '1,000 GAME',
      houseEdge: '2%'
    },
    {
      id: 'dice' as const,
      name: 'Dice Roll',
      description: 'Roll the dice and predict the outcome',
      icon: '🎲',
      status: 'coming_soon' as const,
      minBet: 'TBD',
      maxBet: 'TBD',
      houseEdge: 'TBD'
    },
    {
      id: 'roulette' as const,
      name: 'Roulette',
      description: 'Classic casino roulette with blockchain fairness',
      icon: '🎰',
      status: 'coming_soon' as const,
      minBet: 'TBD',
      maxBet: 'TBD',
      houseEdge: 'TBD'
    }
  ];

  return (
    <div className="space-y-8">
      <div className="text-center">
        <h2 className="text-3xl font-bold mb-4">Provably Fair Games</h2>
        <p className="text-gray-400 max-w-2xl mx-auto">
          Experience truly fair gaming powered by Chainlink VRF. 
          Every outcome is verifiable and tamper-proof.
        </p>
      </div>

      {/* Game Selection */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {games.map((game) => (
          <div
            key={game.id}
            className={`card cursor-pointer transition-all duration-300 ${
              selectedGame === game.id 
                ? 'ring-2 ring-blue-500 transform scale-105' 
                : game.status === 'live' 
                  ? 'hover:transform hover:scale-102' 
                  : 'opacity-50 cursor-not-allowed'
            }`}
            onClick={() => game.status === 'live' && setSelectedGame(game.id)}
          >
            <div className="text-center">
              <div className="text-4xl mb-3">{game.icon}</div>
              <h3 className="text-xl font-bold mb-2">{game.name}</h3>
              <p className="text-gray-400 text-sm mb-4">{game.description}</p>
              
              <div className="space-y-2 text-xs">
                <div className="flex justify-between">
                  <span className="text-gray-500">Min Bet:</span>
                  <span className="text-white">{game.minBet}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Max Bet:</span>
                  <span className="text-white">{game.maxBet}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">House Edge:</span>
                  <span className="text-white">{game.houseEdge}</span>
                </div>
              </div>
              
              <div className="mt-4">
                {game.status === 'live' ? (
                  <div className={`px-3 py-1 rounded-full text-xs font-semibold ${
                    selectedGame === game.id 
                      ? 'bg-blue-600 text-blue-100' 
                      : 'bg-green-600 text-green-100'
                  }`}>
                    {selectedGame === game.id ? 'Selected' : 'Live'}
                  </div>
                ) : (
                  <div className="px-3 py-1 rounded-full text-xs font-semibold bg-gray-600 text-gray-300">
                    Coming Soon
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Game Interface */}
      {selectedGame === 'coinflip' && (
        <div className="space-y-6">
          <div className="text-center">
            <h3 className="text-2xl font-bold mb-2">🪙 CoinFlip Game</h3>
            <p className="text-gray-400">
              Choose heads or tails, place your bet, and let blockchain randomness decide your fate!
            </p>
          </div>

          {!isConnected ? (
            <div className="card text-center">
              <div className="text-4xl mb-4">🔐</div>
              <h4 className="text-xl font-semibold mb-2">Connect Your Wallet</h4>
              <p className="text-gray-400 mb-4">
                You need to connect your wallet to play games
              </p>
            </div>
          ) : (
            <CoinFlipGame />
          )}
        </div>
      )}

      {/* Fairness Information */}
      <div className="bg-green-900 border border-green-600 rounded-lg p-6">
        <h4 className="text-lg font-semibold mb-3 text-green-200">🔒 Provably Fair Gaming</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-green-100">
          <div className="flex items-start space-x-2">
            <span className="text-green-400">🔗</span>
            <div>
              <strong>Chainlink VRF:</strong> True randomness sourced from off-chain oracles, 
              cryptographically verifiable on-chain.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-green-400">🔍</span>
            <div>
              <strong>Transparent:</strong> All game logic is open source and verifiable. 
              No hidden algorithms or unfair advantages.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-green-400">⛓️</span>
            <div>
              <strong>On-Chain:</strong> Every bet, outcome, and payout is recorded permanently 
              on the blockchain for full transparency.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-green-400">🛡️</span>
            <div>
              <strong>Secure:</strong> Smart contracts handle all funds and payouts automatically. 
              No human intervention possible.
            </div>
          </div>
        </div>
      </div>

      {/* Game Stats */}
      <div className="card">
        <h4 className="text-lg font-semibold mb-4">Live Game Statistics</h4>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
          <div>
            <div className="text-2xl font-bold text-blue-400">15,678</div>
            <div className="text-sm text-gray-400">Total Games</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-green-400">1,234</div>
            <div className="text-sm text-gray-400">Active Players</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-yellow-400">100,000</div>
            <div className="text-sm text-gray-400">Prize Pool (GAME)</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-purple-400">2.1%</div>
            <div className="text-sm text-gray-400">Actual House Edge</div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default GameSection;