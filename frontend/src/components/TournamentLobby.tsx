import React from 'react';

export const TournamentLobby = () => {
    return (
        <div className="p-6 bg-gray-800 rounded-lg shadow-xl">
            <h2 className="text-2xl font-bold mb-4 text-white">Tournament Lobby</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="bg-gray-700 p-4 rounded-md">
                    <h3 className="text-lg font-semibold text-white">Weekly Championship</h3>
                    <p className="text-gray-400">Prize Pool: 10,000 GAME</p>
                    <button className="mt-2 w-full py-1 px-3 bg-blue-600 rounded text-white hover:bg-blue-700">
                        Join Now
                    </button>
                </div>
                <div className="bg-gray-700 p-4 rounded-md">
                    <h3 className="text-lg font-semibold text-white">Daily Scrimmage</h3>
                    <p className="text-gray-400">Prize Pool: 1,000 GAME</p>
                    <button className="mt-2 w-full py-1 px-3 bg-blue-600 rounded text-white hover:bg-blue-700">
                        Join Now
                    </button>
                </div>
            </div>
        </div>
    );
};
