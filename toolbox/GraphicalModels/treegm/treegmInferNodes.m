function [logZ, nodeBel,  edgeBel] = treegmInferNodes(model, data)
% Compute marginals on a tree structured graphical model
% using an up-down sweep of belief propagation
%
% INPUT
% model is created by treegmCreate 
% data is an optional D*Nnodes matrix containing local evidence 
% If present, we evaluate the local likelihood using model.localCPDs{t}
% and add this in to the node beliefs
%
% OUTPUT
% logZ = log partition fn
% nodeBel(:,t)
% edgeBel(:,:,e) where model.edges(e,:)=[s t]

if nargin < 2, data = []; end
nodeBel = ones(model.Nstates, model.Nnodes);
Nedges = size(model.edges, 1);
for n=1:model.Nnodes
  nodeBel(:,n) = model.nodePot(:, model.nodePotNdx(n));
end
if ~isempty(data)
  softev = localEvToSoftEv(model, data);
  nodeBel = nodeBel .* softev;
end



[Nstates Nnodes] = size(nodeBel);
Nedges = Nnodes-1;
edgeMsgUp = ones(Nstates, Nedges);
edgeMsgDown = ones(Nstates, Nedges);
% The size of a message is the size of the recipient
logZ = 0;

% Collect to root
for e=1:Nedges
  s  = model.edges(e,1); % src
  t = model.edges(e,2); % destn
  %fprintf('up edge %d, %d->%d\n', e, s, t);
  if model.edgePotNdx(s,t) ~= 0
    edgePot = model.edgePot(:,:,model.edgePotNdx(s,t))';
  else
    edgePot = model.edgePot(:,:,model.edgePotNdx(t,s));
  end
  edgeMsgUp(:,e) = edgePot * nodeBel(:,s);
  [nodeBel(:,t), Zt] = normalize(nodeBel(:,t) .* edgeMsgUp(:,e));
  logZ = logZ + log(Zt);
end

% Distribute from root
for e=Nedges:-1:1 
  s  = model.edges(e,2); % src
  t = model.edges(e,1); % destn
  %fprintf('down edge %d, %d->%d\n', e, s, t);
  if model.edgePotNdx(s,t) ~= 0
    edgePot = model.edgePot(:,:,model.edgePotNdx(s,t))';
  else
    edgePot = model.edgePot(:,:,model.edgePotNdx(t,s));
  end
  % We divide out the message that was sent in to s (from t)
  % to get the product of all-but-one messages
  edgeMsgDown(:,e) = edgePot * (nodeBel(:,s) ./ edgeMsgUp(:,e));
  [nodeBel(:,t)] = normalize(nodeBel(:,t) .* edgeMsgDown(:,e));
end

if nargout < 3, return; end

% Compute edge marginals
% only allocate this much space if the user requests it
edgeBel = ones(model.Nstates, model.Nstates, Nedges);
for e=1:Nedges
  s  = model.edges(e,1); % src
  t = model.edges(e,2); % destn
  bels = nodeBel(:,s) ./ edgeMsgDown(:,e);
  belt = nodeBel(:,t) ./ edgeMsgUp(:,e);
  if model.edgePotNdx(s,t) ~= 0
    edgePot = model.edgePot(:,:,model.edgePotNdx(s,t));
    edgeBel(:,:,e) = normalize(edgePot .* (bels * belt'));
  else
    edgePot = model.edgePot(:,:,model.edgePotNdx(t,s));
    edgeBel(:,:,e) = normalize(edgePot .* (belt * bels'));
  end
   
end


end