'use client';

import React from 'react';
import { useAccount } from 'wagmi';
import StatsCard from './StatsCard';
import RecentActivity from './RecentActivity';

const Dashboard: React.FC = () => {
  const { isConnected, address } = useAccount();

  if (!isConnected) {
    return (
      <div className="card text-center">
        <h2 className="text-2xl font-bold mb-4">Welcome to Crypto Gaming Platform</h2>
        <p className="text-gray-400 mb-6">
          Connect your wallet to access the dashboard and start playing!
        </p>
        <div className="flex justify-center">
          <div className="bg-blue-600 text-white px-6 py-3 rounded-lg">
            Connect Wallet Above
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold">Dashboard</h2>
        <div className="text-sm text-gray-400">
          Connected: {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : ''}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatsCard
          title="GAME Balance"
          value="0"
          subtitle="Utility Tokens"
          icon="💰"
          color="blue"
        />
        <StatsCard
          title="NFT Passes"
          value="0"
          subtitle="Access Passes Owned"
          icon="🎫"
          color="purple"
        />
        <StatsCard
          title="Games Played"
          value="0"
          subtitle="Total Bets Placed"
          icon="🎲"
          color="green"
        />
        <StatsCard
          title="Total Winnings"
          value="0 GAME"
          subtitle="Lifetime Earnings"
          icon="🏆"
          color="yellow"
        />
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="card">
          <h3 className="text-xl font-semibold mb-4">Platform Statistics</h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Total Players</span>
              <span className="font-semibold">1,234</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Games Played</span>
              <span className="font-semibold">15,678</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">Prize Pool</span>
              <span className="font-semibold">100,000 GAME</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-400">House Edge</span>
              <span className="font-semibold">2%</span>
            </div>
          </div>
        </div>

        <RecentActivity />
      </div>

      {/* Quick Actions */}
      <div className="card">
        <h3 className="text-xl font-semibold mb-4">Quick Actions</h3>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <button 
            className="btn-primary text-center py-4"
            onClick={() => document.getElementById('passes')?.scrollIntoView({ behavior: 'smooth' })}
          >
            <div className="text-2xl mb-2">🎫</div>
            <div>Mint NFT Pass</div>
            <div className="text-sm opacity-75">Get access to games</div>
          </button>
          
          <button 
            className="btn-secondary text-center py-4"
            onClick={() => document.getElementById('games')?.scrollIntoView({ behavior: 'smooth' })}
          >
            <div className="text-2xl mb-2">🎲</div>
            <div>Play CoinFlip</div>
            <div className="text-sm opacity-75">Test your luck</div>
          </button>
          
          <div className="btn-warning text-center py-4 cursor-not-allowed opacity-50">
            <div className="text-2xl mb-2">🚰</div>
            <div>Get Test Tokens</div>
            <div className="text-sm opacity-75">Testnet faucet</div>
          </div>
        </div>
      </div>

      {/* Network Warning */}
      <div className="bg-yellow-900 border border-yellow-600 rounded-lg p-4">
        <div className="flex items-center space-x-2">
          <span className="text-yellow-400">⚠️</span>
          <div>
            <h4 className="font-semibold text-yellow-200">Testnet Only</h4>
            <p className="text-yellow-300 text-sm">
              This platform is running on testnet. No real money is involved. 
              Use testnet tokens for all transactions.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;