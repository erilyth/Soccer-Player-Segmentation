input_img = 'soccer_4.png';
img = imread(input_img);
img = imresize(img,[720 NaN],'bicubic');
img_copy = img;

figure,imshow(img);

% Blur the image so only the ground stands out
img = imgaussfilt(img,10);

for i=1:size(img,1)
    for j=1:size(img,2)
        % Try to keep only the ground
        if ~(img(i,j,2) >= img(i,j,1) && img(i,j,1) >= img(i,j,3))
            img(i,j,1) = 0.0;
            img(i,j,2) = 0.0;
            img(i,j,3) = 0.0;
        end
    end
end

% Erode and then dilate so that the boundary is even
img = imerode(img,strel('disk',35));
img = imgaussfilt(img,15);
% Dilate with a larger disk so that the boundary is expanded more than it
% initially was, so we don't miss any players.
img = imdilate(img,strel('disk',40));
img = imgaussfilt(img,15);
% Erode and then dialate to ensure large patches of audience are removed
figure, imshow(img);
img_bw = im2bw(img,0);
img_bw = imerode(img_bw,strel('disk',10));
img_bw = imfill(img_bw,'holes');
%figure,imshow(img_bw);

conn = conndef(ndims(img_bw), 'maximal');
CC = bwconncomp(img_bw, conn);
D1 = regionprops(CC, 'area'); 
areas = [D1.Area];
[maxArea] = max(areas);
allowAreaMax = maxArea;
L = labelmatrix(CC);
img_bw = ismember(L, find([D1.Area] == allowAreaMax));
img_bw = imdilate(img_bw, strel('disk',10));
%figure,imshow(img_bw);

img(:,:,1) = img(:,:,1) .* uint8(img_bw);
img(:,:,2) = img(:,:,2) .* uint8(img_bw);
img(:,:,3) = img(:,:,3) .* uint8(img_bw);

%figure,imshow(img);

img = im2double(img);

for i=1:size(img,1)
    for j=1:size(img,2)
        % Try to keep only the ground
        if ~(img(i,j,1) == 0.0 && img(i,j,2) == 0.0 && img(i,j,3) == 0.0)
            img(i,j,1) = 1.0;
            img(i,j,2) = 1.0;
            img(i,j,3) = 1.0;
        end
    end
end

img = uint8(img);
img_ground = img_copy .* img;
%figure,imshow(img_ground);

% img_ground contains the ground with the players on it (Audience have been removed)

figure,imshow(img_ground, []);

img_cur = img_ground;

for i=1:size(img_cur,1)
    for j=1:size(img_cur,2)
        % Select players only (Roughly)
        if (img_cur(i,j,2) > img_cur(i,j,1) && img_cur(i,j,1) > img_cur(i,j,3))
            img_cur(i,j,1) = 0.0;
            img_cur(i,j,2) = 0.0;
            img_cur(i,j,3) = 0.0;
        end
    end
end

img_cur = imgaussfilt(img_cur, 1);

for i=1:size(img_cur,1)
    for j=1:size(img_cur,2)
        if ~(img_cur(i,j,1) == 0.0 && img_cur(i,j,2) == 0.0 && img_cur(i,j,3) == 0.0)
            img_cur(i,j,1) = 255.0;
            img_cur(i,j,2) = 255.0;
            img_cur(i,j,3) = 255.0;
        end
    end
end

% img_cur now has player blobs marked with white spots

%figure();
%imshow(img_cur, []);

% Get the edges from the image segment consisting of the ground and the
% players on it.
img_cur2 = rgb2gray(img_ground);
[img_cur2_m, img_cur2_d] = imgradient(img_cur2, 'prewitt');

%figure();
%imshow(img_cur2_m, []);

% Consider a sum of the gradient image and the non ground blobs image we
% got earlier. The gradient image would give much finer boundaries.
img_sum = img_cur;
for i=1:size(img_sum,1)
    for j=1:size(img_sum,2)
        % Try to keep only the ground
        if img_cur2_m(i,j,1) >= 150.0 || img_sum(i,j,1) >= 150.0
            img_sum(i,j,1) = 255.0;
            img_sum(i,j,2) = 255.0;
            img_sum(i,j,3) = 255.0;
        else
            img_sum(i,j,1) = 0.0;
            img_sum(i,j,2) = 0.0;
            img_sum(i,j,3) = 0.0;
        end
    end
end

% img_sum is the sum of player blobs along with the gradient of the
% ground+players image (img_ground)
img_sum = uint8(img_sum);

%figure,imshow(img_sum);

% dilate and erode to ensure small uneven boundaries are evened out.
img_sum = imdilate(img_sum,strel('disk',3));
img_sum = imerode(img_sum,strel('disk',3));
img_sum_detail = im2bw(img_sum);
img_sum_old = img_sum_detail;
figure,imshow(img_sum);

img_sum = im2bw(img_sum);
img_sum = imerode(img_sum,strel('disk',2));
conn = conndef(ndims(img_sum), 'maximal');
CC = bwconncomp(img_sum, conn);
D1 = regionprops(CC, 'area'); 
allowAreaMax = (size(img_sum,1) * size(img_sum,2)) / 100;
L = labelmatrix(CC);
img_sum = ismember(L, find([D1.Area] <= allowAreaMax));
img_sum = imdilate(img_sum,strel('disk',2));

%figure,imshow(img_sum);

% ------------

% ISSUES:

% Differentiation between different players

% Small channel logos like soccer_8.png

% Players connected to each other would be removed as their size would be
% considered as too large

% Legs and body disconnected at times, connect them?

% ------------

% Remove the thin lines by erosion, any alternative for this?

bw = img_sum_old;
[H,T,R] = hough(bw);
figure, imshow(img_sum_old), hold on
P  = houghpeaks(H,10,'threshold',ceil(0.3*max(H(:))));
lines = houghlines(bw,T,R,P,'FillGap',5,'MinLength',7);
bw = img_sum;
for k = 1:length(lines)
   xy = [lines(k).point1; lines(k).point2];
   len = norm(lines(k).point1 - lines(k).point2);
   if len >= min(size(img_sum,1),size(img_sum,2)) * 0.15

       plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','green');

       % Plot beginnings and ends of lines
       plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
       plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
       [lnx, lny] = bresenham(xy(1,1), xy(1,2), xy(2,1), xy(2,2));
       for idx = 1:length(lnx)
           width = 9; %Keep these odd
           height = 9; %Keep these odd
           for ix = -(width-1)/2:(width-1)/2
               for iy = -(width-1)/2:(height-1)/2
                   if lny(idx) + iy > 0 && lny(idx) + iy < size(bw,1) && lnx(idx) + ix > 0 && lnx(idx) + ix < size(bw,2)
                       bw(lny(idx)+iy,lnx(idx)+ix) = 0;
                   end
               end
           end
       end
   end
end

bw = imopen(bw,strel('rectangle',[9 9]));

figure, imshow(bw);

% Convert img_sum to black and white so we can apply connected component
% analysis on it.
conn = conndef(ndims(bw), 'maximal');
CC = bwconncomp(bw, conn);
D1 = regionprops(CC, 'area', 'perimeter'); 

areas = [D1.Area];
[meanArea] = mean(areas);
[maxArea] = max(areas);

allowAreaMax = meanArea*4;
allowAreaMin = meanArea/4;

L = labelmatrix(CC);

% Select components whose area >= 3*perimeter(approx for players) && area <= 20*perimeter(approx for players) && area>=10 && area<=maxArea/5 (to remove audience) 

bwfinal = ismember(L, find((([D1.Area] ./ [D1.Perimeter] >= 5) & ([D1.Area] >= allowAreaMin)) | (([D1.Area] <= allowAreaMax) & ([D1.Area] >= allowAreaMin) & ([D1.Area] ./ [D1.Perimeter] < 5))));

for i=1:size(bwfinal,1)
    for j=1:size(bwfinal,2)
        if bwfinal(i,j) == 1 && img_sum_detail(i,j) == 1
            bwfinal(i,j) = 1;
        else
            bwfinal(i,j) = 0;
        end
    end
end

%figure, imshow(bwfinal);

% Dilate the edges a bit and then subtract eroded from that to get
% boundaries of players who have been detected till now.
edges = imdilate(bwfinal,strel('rectangle',[5 5])) - imerode(bwfinal,strel('rectangle',[5 5]));
%figure,imshow(edges);

total_img = img_copy;

% Add the boundary in red color to the original image

for i=1:size(total_img,1)
    for j=1:size(total_img,2)
        if edges(i,j) ~= 0.0
            total_img(i,j,1) = 255.0;
            total_img(i,j,2) = 0.0;
            total_img(i,j,3) = 0.0;
        end
    end
end

% Display the original image with players marked with a red boundary
figure, imshow(total_img);
imwrite(total_img, strcat('outputs/out_',input_img));