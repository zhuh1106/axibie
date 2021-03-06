function [A, A1, A2, A3, A4] = Dspecialquad(t,s,a,b,side)
% DSPECIALQUAD - complex DLP val+grad close-eval Helsing "special quadr" matrix
%
% [A] = Dspecialquad(t,s,a,b)
% [A Az] = Dspecialquad(t,s,a,b) also gives target gradient
% [A Az Azz] = Dspecialquad(t,s,a,b) also gives target gradient and Hessian (needs t.nx)
% [A A1 A2 A3 A4] = Dspecialquad(t,s,a,b) also gives target x,y-derivs
%                   grad_t(D) = [A1, A2]; hess_t(D) = [A3, A4; A4, -A3];
%
% Inputs: t = target seg struct (with column-vec t.x targets in complex plane)
%         s = src node seg struct (with s.x, s.w; amazingly, s.nx not used!)
%         a = panel start, b = panel end, in complex plane.
% Output: A (n_targ * n_src) is source-to-target value matrix
%         An or A1, A2 = source to target normal-deriv (or x,y-deriv) matrices
%
% Note: this returns matrix to eval (1/(2i*pi)) * int_Gamma sigma(y)/(y-x) dy,
%  ie the complex Cauchy integral whose real part is the 2D Laplace DLP.
%
% Efficient only if multiple targs, since O(p^3).
% See Helsing-Ojala 2008 (special quadr Sec 5.1-2), Helsing 2009 mixed (p=16),
% and Helsing's tutorial demo11b.m M1IcompRecFS()
if nargin<5, side = 'i'; end     % interior or exterior
zsc = (b-a)/2; zmid = (b+a)/2; % rescaling factor and midpoint of src segment
y = (s.x-zmid)/zsc; x = (t.x-zmid)/zsc;  % transformed src nodes, targ pts
%figure; plot(x,'.'); hold on; plot(y,'+-'); plot([-1 1],[0 0],'ro'); % debug
N = numel(x);                            % # of targets
p = numel(s.x);                          % assume panel order is # nodes
if N*p==0
    A = 0; A1=0; A2=0;
    return
end
c = (1-(-1).^(1:p))./(1:p);              % Helsing c_k, k = 1..p.
V = ones(p,p); for k=2:p, V(:,k) = V(:,k-1).*y; end  % Vandermonde mat @ nodes
P = zeros(p,N);      % Build P, Helsing's p_k vectorized on all targs...
d = 1.1; inr = abs(x)<=d; ifr = abs(x)>d;      % near & far treat separately
%gam = 1i;
gam = exp(1i*pi/4);  % smaller makes cut closer to panel. barnett 4/17/18
if side == 'e', gam = conj(gam); end   % note gam is a phase, rots branch cut
P(1,:) = log(gam) + log((1-x)./(gam*(-1-x)));  % init p_1 for all targs int

% upwards recurrence for near targets, faster + more acc than quadr...
% (note rotation of cut in log to -Im; so cut in x space is lower unit circle)
if N>1 || (N==1 && inr==1) % Criterion added by Bowei Wu 03/05/15 to ensure inr not empty
    for k=1:p-1, P(k+1,inr) = x(inr).'.*P(k,inr) + c(k); end  % recursion for p_k
end
% fine quadr (no recurrence) for far targets (too inaccurate cf downwards)...
Nf = numel(find(ifr)); wxp = s.wxp/zsc; % rescaled complex speed weights

if Nf>0 % Criterion added by Bowei Wu 03/05/15 to ensure ifr not empty
    P(end,ifr) = sum(((wxp.*V(:,end))*ones(1,Nf))./bsxfun(@minus,y,x(ifr).'));
    for ii = p-1:-1:2
        P( ii,ifr) = (P(ii+1,ifr)-c(ii))./x(ifr).';
    end
end

warning('off','MATLAB:nearlySingularMatrix');
% A = real((V.'\P).'*(1i/(2*pi)));         % solve for special quadr weights
A = ((V.'\P).'*(1i/(2*pi)));         % do not take real for the eval of Stokes DLP non-laplace term. Bowei 10/19/14
%A = (P.'*inv(V))*(1i/(2*pi));   % equiv in exact arith, but not bkw stable.
if nargout>1
    R =  -(kron(ones(p,1),1./(1-x.')) + kron((-1).^(0:p-1).',1./(1+x.'))) +...
        repmat((0:p-1)',[1 N]).*[zeros(1,N); P(1:p-1,:)];  % hypersingular kernel weights of Helsing 2009 eqn (14)
    Az = (V.'\R).'*(1i/(2*pi*zsc));  % solve for targ complex-deriv mat & rescale
    A1 = Az;
    if nargout > 2
        S = -(kron(ones(p,1),1./(1-x.').^2) - kron((-1).^(0:p-1).',1./(1+x.').^2))/2 +...
            repmat((0:p-1)',[1 N]).*[zeros(1,N); R(1:p-1,:)]/2; % supersingular kernel weights
        Azz = (V.'\S).'*(1i/(2*pi*zsc^2));
        if nargout > 3
            A1 = real(Az); A2 = -imag(Az);  % note sign for y-deriv from C-deriv
            A3 = real(Azz); A4 = -imag(Azz);    
        else
            A1 = Az; A2 = Azz; 
        end
    end
end
end