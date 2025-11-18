import React from 'react';

export const SocialHub = () => {
    return (
        <div className="p-6 bg-gray-800 rounded-lg shadow-xl">
            <h2 className="text-2xl font-bold mb-4 text-white">Social Hub</h2>
            <div className="space-y-4">
                <div className="bg-gray-700 p-4 rounded-md">
                    <h3 className="text-lg font-semibold text-white">Your Profile</h3>
                    <div className="flex items-center mt-2">
                        <div className="h-10 w-10 rounded-full bg-gray-500"></div>
                        <div className="ml-3">
                            <p className="text-white font-medium">PlayerOne</p>
                            <p className="text-gray-400 text-sm">Level 5</p>
                        </div>
                    </div>
                </div>
                <div className="bg-gray-700 p-4 rounded-md">
                    <h3 className="text-lg font-semibold text-white">Friends Activity</h3>
                    <ul className="mt-2 space-y-2 text-gray-300">
                        <li>PlayerTwo won 500 GAME in CoinFlip</li>
                        <li>PlayerThree joined Weekly Championship</li>
                    </ul>
                </div>
            </div>
        </div>
    );
};
