'use client';

import React, { useState } from 'react';
import { useAccount } from 'wagmi';

type PassTier = 'Bronze' | 'Silver' | 'Gold';

interface PassTierInfo {
  name: PassTier;
  price: string;
  benefits: string[];
  color: string;
  bgGradient: string;
  icon: string;
}

const PassSection: React.FC = () => {
  const { isConnected } = useAccount();
  const [selectedTier, setSelectedTier] = useState<PassTier>('Bronze');
  const [isMinting, setIsMinting] = useState(false);

  const passTypes: PassTierInfo[] = [
    {
      name: 'Bronze',
      price: '0.001 ETH',
      benefits: [
        'Access to CoinFlip game',
        'Basic statistics tracking',
        'Community access'
      ],
      color: 'text-yellow-600',
      bgGradient: 'from-yellow-800 to-yellow-600',
      icon: '🥉'
    },
    {
      name: 'Silver',
      price: '0.005 ETH',
      benefits: [
        'All Bronze benefits',
        'Higher betting limits',
        'Priority customer support',
        'Special Discord role'
      ],
      color: 'text-gray-400',
      bgGradient: 'from-gray-600 to-gray-400',
      icon: '🥈'
    },
    {
      name: 'Gold',
      price: '0.01 ETH',
      benefits: [
        'All Silver benefits',
        'Maximum betting limits',
        'Exclusive tournaments',
        'VIP rewards program',
        'Early access to new games'
      ],
      color: 'text-yellow-400',
      bgGradient: 'from-yellow-600 to-yellow-400',
      icon: '🥇'
    }
  ];

  const handleMint = async () => {
    if (!isConnected) return;
    
    setIsMinting(true);
    try {
      // In a real app, this would call the contract
      console.log(`Minting ${selectedTier} pass...`);
      await new Promise(resolve => setTimeout(resolve, 2000)); // Simulate transaction
      alert(`${selectedTier} pass minted successfully!`);
    } catch (error) {
      console.error('Minting failed:', error);
      alert('Minting failed. Please try again.');
    } finally {
      setIsMinting(false);
    }
  };

  return (
    <div className="space-y-8">
      <div className="text-center">
        <h2 className="text-3xl font-bold mb-4">NFT Game Passes</h2>
        <p className="text-gray-400 max-w-2xl mx-auto">
          Mint an NFT pass to access games and unlock exclusive benefits. 
          Choose your tier and start your gaming journey!
        </p>
      </div>

      {/* Pass Tier Selection */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {passTypes.map((pass) => (
          <div
            key={pass.name}
            className={`card cursor-pointer transition-all duration-300 ${
              selectedTier === pass.name 
                ? 'ring-2 ring-blue-500 transform scale-105' 
                : 'hover:transform hover:scale-102'
            }`}
            onClick={() => setSelectedTier(pass.name)}
          >
            <div className="text-center">
              <div className="text-4xl mb-3">{pass.icon}</div>
              <h3 className="text-xl font-bold mb-2">{pass.name} Pass</h3>
              <div className={`text-2xl font-bold mb-4 ${pass.color}`}>
                {pass.price}
              </div>
              
              <div className="space-y-2 text-left">
                {pass.benefits.map((benefit, index) => (
                  <div key={index} className="flex items-center space-x-2 text-sm">
                    <span className="text-green-400">✓</span>
                    <span className="text-gray-300">{benefit}</span>
                  </div>
                ))}
              </div>
              
              {selectedTier === pass.name && (
                <div className={`mt-4 p-2 rounded-lg bg-gradient-to-r ${pass.bgGradient} opacity-20`}>
                  <span className="text-white text-sm font-semibold">Selected</span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Minting Section */}
      <div className="card max-w-lg mx-auto">
        <h3 className="text-xl font-semibold mb-4 text-center">Mint Your Pass</h3>
        
        <div className="space-y-4">
          <div className="text-center">
            <div className="text-3xl mb-2">
              {passTypes.find(p => p.name === selectedTier)?.icon}
            </div>
            <p className="text-lg font-semibold">{selectedTier} Pass</p>
            <p className={`text-xl font-bold ${passTypes.find(p => p.name === selectedTier)?.color}`}>
              {passTypes.find(p => p.name === selectedTier)?.price}
            </p>
          </div>

          {!isConnected ? (
            <div className="text-center py-4">
              <p className="text-gray-400 mb-4">Connect your wallet to mint an NFT pass</p>
              <div className="btn-primary inline-block opacity-50 cursor-not-allowed px-6 py-2">
                Connect Wallet First
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="bg-gray-700 p-3 rounded-lg">
                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Network:</span>
                  <span className="text-white">Testnet</span>
                </div>
                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Gas Fee:</span>
                  <span className="text-white">~0.001 ETH</span>
                </div>
                <div className="flex justify-between items-center text-sm">
                  <span className="text-gray-400">Total:</span>
                  <span className="text-white font-semibold">
                    {passTypes.find(p => p.name === selectedTier)?.price}
                  </span>
                </div>
              </div>

              <button
                className="btn-primary w-full py-3 text-lg font-semibold"
                onClick={handleMint}
                disabled={isMinting}
              >
                {isMinting ? (
                  <div className="flex items-center justify-center space-x-2">
                    <div className="loading-spinner w-5 h-5"></div>
                    <span>Minting...</span>
                  </div>
                ) : (
                  `Mint ${selectedTier} Pass`
                )}
              </button>
            </div>
          )}

          <div className="text-center text-sm text-gray-500">
            <p>⚠️ This will create a transaction on the testnet</p>
          </div>
        </div>
      </div>

      {/* Pass Collection */}
      <div className="card">
        <h3 className="text-xl font-semibold mb-4">My NFT Passes</h3>
        
        <div className="text-center py-8 text-gray-500">
          <div className="text-4xl mb-2">🎫</div>
          <p>No passes owned yet</p>
          <p className="text-sm">Mint your first pass to get started!</p>
        </div>
      </div>

      {/* Benefits Explanation */}
      <div className="bg-blue-900 border border-blue-600 rounded-lg p-6">
        <h4 className="text-lg font-semibold mb-3 text-blue-200">Why Do I Need a Pass?</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-blue-100">
          <div className="flex items-start space-x-2">
            <span className="text-blue-400">🔐</span>
            <div>
              <strong>Access Control:</strong> Passes are required to play games and access premium features.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-blue-400">🎯</span>
            <div>
              <strong>Tier Benefits:</strong> Higher tiers unlock better limits and exclusive perks.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-blue-400">🔒</span>
            <div>
              <strong>Ownership:</strong> Your pass is a real NFT that you fully own and control.
            </div>
          </div>
          <div className="flex items-start space-x-2">
            <span className="text-blue-400">🚀</span>
            <div>
              <strong>Future Proof:</strong> Passes will work with all future games and features.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PassSection;