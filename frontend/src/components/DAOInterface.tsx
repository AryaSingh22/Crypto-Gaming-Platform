import React from 'react';

export const DAOInterface = () => {
    return (
        <div className="p-6 bg-gray-800 rounded-lg shadow-xl">
            <h2 className="text-2xl font-bold mb-4 text-white">Governance DAO</h2>
            <div className="space-y-4">
                <div className="bg-gray-700 p-4 rounded-md">
                    <h3 className="text-xl font-semibold text-white">Active Proposals</h3>
                    <p className="text-gray-400">No active proposals at the moment.</p>
                </div>
                <button className="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700">
                    Create Proposal
                </button>
            </div>
        </div>
    );
};
