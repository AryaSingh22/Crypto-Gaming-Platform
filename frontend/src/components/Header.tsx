'use client';

import React from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useNetwork } from 'wagmi';

const Header: React.FC = () => {
  const { isConnected } = useAccount();
  const { chain } = useNetwork();

  return (
    <header className="bg-gray-800 border-b border-gray-700 sticky top-0 z-40">
      <div className="container mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <div className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-500 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-xl">🎮</span>
            </div>
            <span className="text-xl font-bold gradient-text">
              GameFi Platform
            </span>
          </div>

          {/* Navigation */}
          <nav className="hidden md:flex items-center space-x-6">
            <a 
              href="#dashboard" 
              className="text-gray-300 hover:text-white transition-colors duration-200"
            >
              Dashboard
            </a>
            <a 
              href="#passes" 
              className="text-gray-300 hover:text-white transition-colors duration-200"
            >
              NFT Passes
            </a>
            <a 
              href="#games" 
              className="text-gray-300 hover:text-white transition-colors duration-200"
            >
              Games
            </a>
          </nav>

          {/* Wallet Connection */}
          <div className="flex items-center space-x-4">
            {isConnected && chain && (
              <div className="hidden sm:flex items-center space-x-2 bg-gray-700 px-3 py-1 rounded-lg">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span className="text-sm text-gray-300">{chain.name}</span>
              </div>
            )}
            <ConnectButton />
          </div>
        </div>

        {/* Mobile Navigation */}
        <nav className="md:hidden mt-4 flex space-x-4 overflow-x-auto">
          <a 
            href="#dashboard" 
            className="text-gray-300 hover:text-white transition-colors duration-200 whitespace-nowrap"
          >
            Dashboard
          </a>
          <a 
            href="#passes" 
            className="text-gray-300 hover:text-white transition-colors duration-200 whitespace-nowrap"
          >
            NFT Passes
          </a>
          <a 
            href="#games" 
            className="text-gray-300 hover:text-white transition-colors duration-200 whitespace-nowrap"
          >
            Games
          </a>
        </nav>
      </div>
    </header>
  );
};

export default Header;