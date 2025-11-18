import React, { useState } from 'react';

export const BridgeInterface = () => {
  const [amount, setAmount] = useState('');
  const [targetChain, setTargetChain] = useState('137'); // Default Polygon

  const handleBridge = async () => {
    // Implement bridge logic here
    console.log(`Bridging ${amount} to chain ${targetChain}`);
  };

  return (
    <div className="p-6 bg-gray-800 rounded-lg shadow-xl">
      <h2 className="text-2xl font-bold mb-4 text-white">Cross-Chain Bridge</h2>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300">Amount</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="mt-1 block w-full rounded-md bg-gray-700 border-gray-600 text-white"
            placeholder="0.0"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-300">Target Chain</label>
          <select
            value={targetChain}
            onChange={(e) => setTargetChain(e.target.value)}
            className="mt-1 block w-full rounded-md bg-gray-700 border-gray-600 text-white"
          >
            <option value="137">Polygon</option>
            <option value="42161">Arbitrum</option>
            <option value="324">zkSync Era</option>
          </select>
        </div>
        <button
          onClick={handleBridge}
          className="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Bridge Assets
        </button>
      </div>
    </div>
  );
};
