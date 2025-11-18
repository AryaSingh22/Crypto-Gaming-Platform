'use client';

import React from 'react';
import Header from '@/components/Header';
import GameDashboard from '@/components/GameDashboard';

export default function HomePage() {
  return (
    <div className="min-h-screen">
      <Header />
      
      <main className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-4xl md:text-6xl font-bold text-center mb-4 bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
            Crypto Gaming Platform
          </h1>
          <p className="text-xl text-gray-300 text-center max-w-2xl mx-auto">
            Experience provably fair gaming with NFT passes and utility tokens. 
            Play CoinFlip and win big on the blockchain!
          </p>
        </div>

        {/* Unified Gaming Dashboard */}
        <section id="dashboard">
          <GameDashboard />
        </section>
      </main>

      <footer className="bg-gray-800 border-t border-gray-700 py-8 mt-16">
        <div className="container mx-auto px-4">
          <div className="text-center text-gray-400">
            <p className="mb-2">
              © 2024 Crypto Gaming Platform. Built with ❤️ for the blockchain gaming community.
            </p>
            <p className="text-sm">
              <span className="text-yellow-400">⚠️ Testnet Only:</span> This is a demo application. 
              No real money is involved. For educational purposes only.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}