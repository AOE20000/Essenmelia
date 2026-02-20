// Initialize state
const state = _state;
state.username = state.username || 'lpwcnm'; // Default user
state.defaultTags = state.defaultTags || 'Bangumi';
state.collectionList = state.collectionList || [];
state.loading = false;

// Cache for items to avoid proxy overhead
let cachedItems = [];

function getStatusText(type) {
  switch (type) {
    case 1: return '想看';
    case 2: return '看过';
    case 3: return '在看';
    case 4: return '搁置';
    case 5: return '抛弃';
    default: return '未知';
  }
}

// Fetch collections from Bangumi API
async function fetchCollections() {
  if (state.loading) return;
  
  const username = state.username ? state.username.trim() : '';
  if (!username) {
    await essenmelia.showSnackBar('请输入用户名');
    return;
  }

  state.loading = true;
  // Show loading indicator
  state.collectionList = [{
    type: 'container',
    props: { height: 100, padding: 20 },
    children: [{
      type: 'text', 
      props: { text: '加载中...', textAlign: 'center' }
    }]
  }];

  try {
    const url = `https://api.bgm.tv/v0/users/${username}/collections`;
    console.log('Fetching collections from: ' + url);
    const resStr = await essenmelia.httpGet(url, {});
    console.log('Response received, length: ' + (resStr ? resStr.length : 'null'));
    
    // Check if resStr is already an object (auto-parsed by bridge?)
    let res;
    if (typeof resStr === 'object') {
      res = resStr;
      console.log('Response is already an object');
    } else {
      res = JSON.parse(resStr);
      console.log('JSON parsed successfully');
    }
    
    if (res && res.data) {
      const items = res.data;
      cachedItems = items; // Cache items
      
      const newUiList = [];

      // Add "Import All" button at the top
      newUiList.push({
        type: 'row',
        props: {
            mainAxisAlignment: 'end',
            padding: [16, 8, 16, 8]
        },
        children: [{
            type: 'button',
            props: {
                label: '一键导入全部',
                icon: 0xe161, // save_alt
                variant: 'filled',
                onTap: 'importAll' 
            }
        }]
      });

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const subject = item.subject || {};
        const images = subject.images || {};
        const cover = images.common || images.medium || images.large || '';
        const eps = subject.eps || 0;
        const watched = item.ep_status || 0;
        
        // Build UI component for each item
        const card = {
          type: 'card',
          props: {
            variant: 'filled',
            margin: [0, 0, 0, 12],
            padding: 0
          },
          children: [{
            type: 'row',
            props: {
              crossAxisAlignment: 'start'
            },
            children: [
              // Cover Image
              {
                type: 'image',
                props: {
                  url: cover,
                  width: 80,
                  height: 120,
                  fit: 'cover',
                  borderRadius: 12
                }
              },
              // Info Column
              {
                type: 'expanded',
                children: [{
                  type: 'column',
                  props: {
                    padding: [12, 8, 12, 8],
                    crossAxisAlignment: 'start'
                  },
                  children: [
                    // Title
                    {
                      type: 'text',
                      props: {
                        text: subject.name_cn || subject.name,
                        style: 'titleMedium',
                        maxLines: 1,
                        bold: true
                      }
                    },
                    // Subtitle (Original Name)
                    {
                      type: 'text',
                      props: {
                        text: subject.name,
                        style: 'bodySmall',
                        maxLines: 1,
                        textColor: 'outline'
                      }
                    },
                    // Summary (if available)
                    subject.short_summary ? {
                      type: 'text',
                      props: {
                        text: subject.short_summary,
                        style: 'bodySmall',
                        maxLines: 2,
                        textColor: 'onSurfaceVariant',
                        padding: [0, 4, 0, 4]
                      }
                    } : { type: 'sized_box', props: { height: 4 } },
                    // Status/Score Row
                    {
                      type: 'row',
                      props: {
                        padding: [0, 4, 0, 0]
                      },
                      children: [
                        // Status Badge
                        {
                          type: 'container',
                          props: {
                            color: 'secondaryContainer',
                            padding: [6, 2, 6, 2],
                            borderRadius: 4,
                            margin: [0, 8, 0, 0]
                          },
                          children: [{
                            type: 'text',
                            props: {
                              text: getStatusText(item.type),
                              style: 'labelSmall',
                              textColor: 'onSecondaryContainer'
                            }
                          }]
                        },
                        // User Rating
                        item.rate > 0 ? {
                          type: 'container',
                          props: {
                            color: 'primaryContainer',
                            padding: [6, 2, 6, 2],
                            borderRadius: 4,
                            margin: [0, 8, 0, 0]
                          },
                          children: [{
                            type: 'text',
                            props: {
                              text: '评分: ' + item.rate,
                              style: 'labelSmall',
                              textColor: 'onPrimaryContainer'
                            }
                          }]
                        } : { type: 'sized_box' },
                        // Global Score
                        {
                          type: 'container',
                          props: {
                            color: 'surfaceContainerHighest',
                            padding: [6, 2, 6, 2],
                            borderRadius: 4
                          },
                          children: [{
                            type: 'text',
                            props: {
                              text: '均分: ' + (subject.score || '-'),
                              style: 'labelSmall',
                              textColor: 'onSurfaceVariant'
                            }
                          }]
                        }
                      ]
                    },
                    // Add to Event Button
                    {
                        type: 'row',
                        props: {
                            mainAxisAlignment: 'end',
                            padding: [0, 8, 0, 0]
                        },
                        children: [{
                            type: 'button',
                            props: {
                                label: '导入日程',
                                icon: 0xe145, // add
                                variant: 'tonal',
                                onTap: 'addToEvent?title=' + encodeURIComponent(subject.name_cn || subject.name) + 
                                       '&originalTitle=' + encodeURIComponent(subject.name || '') +
                                       '&cover=' + encodeURIComponent(cover) +
                                       '&eps=' + eps + 
                                       '&watched=' + watched +
                                       '&summary=' + encodeURIComponent(subject.short_summary || '') +
                                       '&score=' + (subject.score || '0') +
                                       '&userScore=' + (item.rate || '0') +
                                       '&userComment=' + encodeURIComponent(item.comment || '') +
                                       '&userTags=' + encodeURIComponent((item.tags || []).join(',')) +
                                       '&collectionStatus=' + item.type +
                                       '&subjectId=' + (subject.id || '')
                            }
                        }]
                    }
                  ]
                }]
              }
            ]
          }]
        };
        newUiList.push(card);
      }
      
      state.collectionList = newUiList;
    } else {
      state.collectionList = [{
        type: 'text',
        props: { text: '未找到数据', textAlign: 'center', padding: 20 }
      }];
    }
  } catch (e) {
    console.log('Error fetching collections', e);
    await essenmelia.showSnackBar('加载失败: ' + e);
    state.collectionList = [{
      type: 'text',
      props: { text: '加载失败: ' + e, textColor: 'error', textAlign: 'center', padding: 20 }
    }];
  }

  state.loading = false;
}

async function addToEvent(args, silent) {
  const title = args.title;
  const originalTitle = args.originalTitle || '';
  const cover = args.cover;
  const eps = parseInt(args.eps || '0');
  const watched = parseInt(args.watched || '0');
  const summary = args.summary || '';
  const score = args.score || '0';
  const userScore = args.userScore || '0';
  const userComment = args.userComment || '';
  const userTagsStr = args.userTags || '';
  const collectionStatusType = parseInt(args.collectionStatus || '0');
  const subjectId = args.subjectId || '';
  
  // Parse tags
  let tags = ['Bangumi', 'Anime'];
  
  // Add collection status tag
  const statusText = getStatusText(collectionStatusType);
  if (statusText !== '未知') {
      tags.push(statusText);
  }
  
  // Add user tags
  if (userTagsStr) {
      const userTags = userTagsStr.split(',').map(t => t.trim()).filter(t => t.length > 0);
      // Limit to top 3 user tags to avoid clutter
      tags = tags.concat(userTags.slice(0, 3)); 
  }

  if (state.defaultTags) {
      const extraTags = state.defaultTags.split(/[,，]/).map(t => t.trim()).filter(t => t.length > 0);
      tags = tags.concat(extraTags);
  }
  
  // Deduplicate tags
  tags = [...new Set(tags)];

  // Build description
  let description = '';
  if (originalTitle && originalTitle !== title) {
      description += `原名: ${originalTitle}\n`;
  }
  if (summary) {
      description += `简介: ${summary}\n\n`;
  }
  
  description += `Bangumi ID: ${subjectId}\n`;
  if (subjectId) {
      description += `Link: https://bgm.tv/subject/${subjectId}\n`;
  }
  
  if (score !== '0') description += `评分: ${score}\n`;
  if (userScore !== '0') description += `我的评分: ${userScore}\n`;
  if (userComment) description += `我的短评: ${userComment}\n`;
  
  description += `\nCover: ${cover}\nFrom Bangumi Collection Extension`;

  // Build steps
  const steps = [];
  if (eps > 0) {
      for (let i = 1; i <= eps; i++) {
          steps.push({
              description: `第 ${i} 话`,
              completed: i <= watched,
              timestamp: new Date().toISOString()
          });
      }
  }

  try {
    await essenmelia.addEvent({
      title: '追番: ' + title,
      description: description,
      tags: tags,
      imageUrl: cover,
      steps: steps,
      stepDisplayMode: 'number',
      stepSuffix: '话'
    });
    if (!silent) await essenmelia.showSnackBar('已添加到日程: ' + title);
  } catch (e) {
    if (!silent) await essenmelia.showSnackBar('添加失败: ' + e);
    throw e;
  }
}

async function importAll() {
    if (!cachedItems || cachedItems.length === 0) {
        await essenmelia.showSnackBar('没有可导入的项目');
        return;
    }
    
    await essenmelia.showSnackBar('开始导入 ' + cachedItems.length + ' 个项目...');
    
    let successCount = 0;
    for (let i = 0; i < cachedItems.length; i++) {
        const item = cachedItems[i];
        const subject = item.subject || {};
        const images = subject.images || {};
        const cover = images.common || images.medium || images.large || '';
        const eps = subject.eps || 0;
        const watched = item.ep_status || 0;
        const title = subject.name_cn || subject.name;
        
        try {
            await addToEvent({
                title: title,
                originalTitle: subject.name,
                cover: cover,
                eps: eps,
                watched: watched,
                summary: subject.short_summary,
                score: subject.score,
                userScore: item.rate,
                userComment: item.comment,
                userTags: (item.tags || []).join(','),
                collectionStatus: item.type,
                subjectId: subject.id
            }, true); // silent mode
            successCount++;
        } catch (e) {
            console.log('Import failed for ' + title + ': ' + e);
        }
        
        // Optional: throttle to avoid freezing UI or hitting DB too hard
        // await new Promise(r => setTimeout(r, 50)); 
    }
    
    await essenmelia.showSnackBar('导入完成: 成功 ' + successCount + '/' + cachedItems.length);
}

// Lifecycle hook
function onLoad() {
  console.log('Bangumi Collection extension loaded');
  return { status: 'loaded' };
}
