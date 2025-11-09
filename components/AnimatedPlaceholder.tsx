import React from 'react';

const CrystalFacet: React.FC<{ rotation: number; translateZ: number }> = ({ rotation, translateZ }) => {
  return (
    <div
      className="absolute w-full h-full border border-slate-100/20 dark:border-slate-300/20 bg-slate-400/10 dark:bg-slate-500/10 backdrop-blur-sm"
      style={{
        transform: `rotateY(${rotation}deg) translateZ(${translateZ}px)`,
      }}
    />
  );
};

const Sparkle: React.FC<{ top: string; left: string; delay: string; duration: string }> = ({ top, left, delay, duration }) => {
    return (
        <div 
            className="absolute w-1 h-1 bg-white rounded-full animate-sparkle-fade opacity-0"
            style={{ top, left, animationDelay: delay, animationDuration: duration }}
        />
    )
}

const AnimatedPlaceholder: React.FC<{ className?: string }> = ({ className }) => {
  // Using a fixed size for the crystal for easier calculation
  const crystalWidth = 80; 
  const translateZ = crystalWidth / 2 / Math.tan(Math.PI / 6); // Calculation for a regular hexagon

  return (
    <div className={`relative overflow-hidden bg-slate-200 dark:bg-slate-900 ${className} isolate`}>
      {/* 1. Pulsing Background */}
      <div 
        className="absolute inset-0 animate-background-pulse"
        style={{
          backgroundImage: 'radial-gradient(ellipse at center, var(--tw-gradient-stops))',
          '--tw-gradient-from': 'rgba(199, 210, 254, 0.6)', // indigo-200
          '--tw-gradient-to': 'transparent',
        }}
      />
      <div 
        className="absolute inset-0 animate-background-pulse dark:opacity-50"
        style={{
          backgroundImage: 'radial-gradient(ellipse at center, var(--tw-gradient-stops))',
          '--tw-gradient-from': 'rgba(30, 41, 59, 1)', // slate-800
          '--tw-gradient-to': 'transparent',
           animationDelay: '-5s'
        }}
      />
      
      {/* Sparkles */}
      <Sparkle top="20%" left="30%" delay="0s" duration="4s" />
      <Sparkle top="80%" left="25%" delay="-2s" duration="3.5s" />
      <Sparkle top="35%" left="75%" delay="-1s" duration="4.5s" />
      <Sparkle top="60%" left="85%" delay="-3s" duration="3s" />

      {/* 2. Crystal Structure */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div
          className="animate-crystal-rotate"
          style={{
            width: `${crystalWidth}px`,
            height: `${crystalWidth * 1.5}px`, // Make it taller
            transformStyle: 'preserve-3d',
          }}
        >
          {[0, 60, 120, 180, 240, 300].map((angle) => (
            <CrystalFacet key={angle} rotation={angle} translateZ={translateZ} />
          ))}
        </div>
      </div>
      
       {/* 3. Light Sheen Effect */}
       <div 
        className="absolute inset-0 w-full h-full animate-light-ray-sweep mix-blend-overlay dark:mix-blend-plus-lighter pointer-events-none"
        style={{
            backgroundImage: 'linear-gradient(to right, transparent, white, transparent)',
        }}
       />

    </div>
  );
};
export default AnimatedPlaceholder;
