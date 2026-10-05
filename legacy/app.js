/* 2026 Modern Design Logic */

const balance = document.getElementById('balance');
const money_plus = document.getElementById('money-plus');
const money_minus = document.getElementById('money-minus');
const listPreview = document.getElementById('list-preview');
const listFull = document.getElementById('list');
const form = document.getElementById('form');
const text = document.getElementById('text');
const amount = document.getElementById('amount');
const quickIncomeForm = document.getElementById('quickIncomeForm');
const quickIncomeAmount = document.getElementById('quickIncomeAmount');
const expenseChartCanvas = document.getElementById('expenseChart');
const currencySelector = document.getElementById('currencySelector');
const pageTitle = document.getElementById('pageTitle');

// Goal Form Elements
const goalForm = document.getElementById('goalForm');
const goalInputName = document.getElementById('goalInputName');
const goalInputAmount = document.getElementById('goalInputAmount');
const displayGoalName = document.getElementById('displayGoalName');

// Navigation Elements
const navItems = document.querySelectorAll('.nav-item');
const viewSections = document.querySelectorAll('.view-section');

// Modal Elements
const profileModal = document.getElementById('profileModal');
const sidebarProfileTrigger = document.getElementById('sidebarProfileTrigger');
const mobileProfileTrigger = document.getElementById('mobileProfileTrigger');
const userNameInput = document.getElementById('userName');
const saveProfileBtn = document.getElementById('saveProfile');
const cancelProfileBtn = document.getElementById('cancelProfile');
const closeModalBtn = document.getElementById('closeModal');
const sidebarProfileAvatar = document.getElementById('sidebarProfileAvatar');
const mobileProfileAvatar = document.getElementById('mobileProfileAvatar');
const sidebarProfileName = document.getElementById('sidebarProfileName');
const profilePreview = document.getElementById('profilePreview');
const useGeneratedAvatarBtn = document.getElementById('useGeneratedAvatar');
const uploadPictureBtn = document.getElementById('uploadPictureBtn');
const profilePictureInput = document.getElementById('profilePictureInput');

// Statement Elements
const statementToggle = document.getElementById('statementToggle');
const statementEmail = document.getElementById('statementEmail');
const saveStatementBtn = document.getElementById('saveStatementBtn');
const statementMetaContainer = document.getElementById('statementMetaContainer');
const nextStatementDate = document.getElementById('nextStatementDate');

// Data State
const localStorageTransactions = JSON.parse(localStorage.getItem('transactions'));
let transactions = localStorage.getItem('transactions') !== null ? localStorageTransactions : [];
let chartInstance = null;
let currentCurrency = localStorage.getItem('currency') || '$';
let userName = localStorage.getItem('userName') || 'User';
let profilePicture = localStorage.getItem('profilePicture') || null;
let useCustomPicture = localStorage.getItem('useCustomPicture') === 'true';

// Automation State
let statementEnabled = localStorage.getItem('statementEnabled') === 'true';
let statementEmailValue = localStorage.getItem('statementEmailValue') || '';

// Goal State
let goalName = localStorage.getItem('goalName') || 'Emergency Fund';
let goalAmount = parseFloat(localStorage.getItem('goalAmount')) || 100000;

// Initialization
function init() {
    renderTransactions();
    updateValues();
    updateChart();
    initStatementService();
    initGoalForm();
}

function initGoalForm() {
    if (goalInputName && goalInputAmount) {
        goalInputName.value = goalName;
        goalInputAmount.value = goalAmount;
    }
}

// Navigation Logic
function handleNavigation(e) {
    const targetItem = e.currentTarget;
    const targetViewId = targetItem.getAttribute('data-target');
    const title = targetItem.getAttribute('data-title');

    // Update active class on nav items
    navItems.forEach(item => {
        if (item.getAttribute('data-target') === targetViewId) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    // Show target view, hide others
    viewSections.forEach(section => {
        if (section.id === targetViewId) {
            section.classList.add('active');
        } else {
            section.classList.remove('active');
        }
    });

    // Update Page Title
    if (pageTitle && title) {
        pageTitle.innerText = title;
    }

    // Re-render chart if navigating to dashboard to ensure correct sizing
    if (targetViewId === 'view-dashboard') {
        setTimeout(updateChart, 50); // slight delay for layout calc
    }
}

navItems.forEach(item => {
    item.addEventListener('click', handleNavigation);
});

// Transaction Functions
function addTransaction(e) {
    e.preventDefault();
    if (text.value.trim() === '' || amount.value.trim() === '') {
        return;
    }

    const transaction = {
        id: generateID(),
        text: text.value,
        amount: -Math.abs(+amount.value) // Ensure it's an expense
    };

    transactions.push(transaction);
    renderTransactions();
    updateValues();
    updateLocalStorage();
    updateChart();

    text.value = '';
    amount.value = '';
}

function generateID() {
    return Math.floor(Math.random() * 100000000);
}

function renderTransactions() {
    if (listFull) listFull.innerHTML = '';
    if (listPreview) listPreview.innerHTML = '';
    
    // Sort transactions recent first
    const sorted = [...transactions].reverse();

    sorted.forEach((transaction, index) => {
        addTransactionDOM(transaction, listFull);
        
        // Only add top 3 to preview
        if (index < 3 && listPreview) {
            addTransactionDOM(transaction, listPreview);
        }
    });
}

function addTransactionDOM(transaction, container) {
    if (!container) return;
    const sign = transaction.amount < 0 ? '-' : '+';
    const item = document.createElement('li');
    const amountClass = transaction.amount < 0 ? 'minus' : 'plus';

    item.innerHTML = `
        <div class="activity-info">
            <span class="activity-name">${transaction.text}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 1rem;">
            <span class="activity-amount ${amountClass}">${sign}${currentCurrency}${Math.abs(transaction.amount).toFixed(2)}</span>
            <button class="delete-action" onclick="removeTransaction(${transaction.id})" title="Delete"><i class="fa-solid fa-xmark"></i></button>
        </div>
    `;
    container.appendChild(item);
}

function updateValues() {
    const amounts = transactions.map(transaction => transaction.amount);
    const total = amounts.reduce((acc, item) => (acc += item), 0);
    const income = amounts.filter(item => item > 0).reduce((acc, item) => (acc += item), 0);
    const expense = amounts.filter(item => item < 0).reduce((acc, item) => (acc += item), 0) * -1;

    if (balance) balance.innerText = `${currentCurrency}${total.toFixed(2)}`;
    if (money_plus) money_plus.innerText = `+${currentCurrency}${income.toFixed(2)}`;
    if (money_minus) money_minus.innerText = `-${currentCurrency}${expense.toFixed(2)}`;
    
    updateGoalProgress(total.toFixed(2));
    updateSpendVelocity(expense);
}

function removeTransaction(id) {
    transactions = transactions.filter(transaction => transaction.id !== id);
    updateLocalStorage();
    init();
}

function updateLocalStorage() {
    localStorage.setItem('transactions', JSON.stringify(transactions));
}

// Charting Logic
function updateChart() {
    if (!expenseChartCanvas) return;
    const amounts = transactions.map(transaction => transaction.amount);
    const income = amounts.filter(item => item > 0).reduce((acc, item) => (acc += item), 0);
    const expense = amounts.filter(item => item < 0).reduce((acc, item) => (acc += item), 0) * -1;

    if (chartInstance) {
        chartInstance.destroy();
    }

    const incomeColor = '#059669'; 
    const expenseColor = '#BE123C'; 
    const emptyColor = '#E4E4E7';
    const textColor = '#52525B';

    const data = [income, expense];
    const isDataEmpty = income === 0 && expense === 0;

    chartInstance = new Chart(expenseChartCanvas, {
        type: 'doughnut',
        data: {
            labels: ['Income', 'Expense'],
            datasets: [{
                data: isDataEmpty ? [1] : data,
                backgroundColor: isDataEmpty ? [emptyColor] : [incomeColor, expenseColor],
                borderWidth: 0,
                hoverOffset: isDataEmpty ? 0 : 4,
                cutout: '80%'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: textColor, font: { family: "'Outfit', sans-serif" }, usePointStyle: true, padding: 20 },
                    display: !isDataEmpty
                },
                tooltip: {
                    enabled: !isDataEmpty,
                    backgroundColor: '#FFFFFF',
                    titleColor: '#18181B',
                    bodyColor: '#52525B',
                    borderColor: 'rgba(0,0,0,0.1)',
                    borderWidth: 1, padding: 12, cornerRadius: 12, displayColors: false,
                    callbacks: {
                        label: function(context) { return `${context.label}: ${currentCurrency}${context.raw.toFixed(2)}`; }
                    }
                }
            }
        }
    });
}

// Statement Service Logic
function initStatementService() {
    if (statementToggle && statementEmail) {
        statementToggle.checked = statementEnabled;
        statementEmail.value = statementEmailValue;
        updateStatementUI();
    }
}

function updateStatementUI() {
    if (!statementMetaContainer) return;
    if (statementEnabled && statementEmailValue !== '') {
        statementMetaContainer.style.display = 'flex';
        const today = new Date();
        const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
        nextStatementDate.innerText = nextMonth.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    } else {
        statementMetaContainer.style.display = 'none';
    }
}

function saveStatementConfig() {
    statementEnabled = statementToggle.checked;
    statementEmailValue = statementEmail.value.trim();
    
    if (statementEnabled && statementEmailValue === '') {
        alert("Please enter a valid Gmail address to enable automated statements.");
        statementToggle.checked = false;
        statementEnabled = false;
    }
    
    localStorage.setItem('statementEnabled', statementEnabled);
    localStorage.setItem('statementEmailValue', statementEmailValue);
    updateStatementUI();
    
    const originalText = saveStatementBtn.innerText;
    saveStatementBtn.innerHTML = 'Saved <i class="fa-solid fa-check"></i>';
    setTimeout(() => { saveStatementBtn.innerText = originalText; }, 2000);
}

// Goal Logic
function updateGoalProgress(currentTotal) {
    let currentSavings = Math.max(0, parseFloat(currentTotal));
    
    const percent = goalAmount > 0 ? Math.min(100, Math.round((currentSavings / goalAmount) * 100)) : 0;
    const ring = document.getElementById('goalRing');
    if (!ring) return;
    
    const circleLength = 2 * Math.PI * 70; // r=70 for the larger ring
    ring.style.strokeDasharray = `${circleLength}`;
    ring.style.strokeDashoffset = circleLength - (percent / 100) * circleLength;
    
    document.getElementById('goalPercent').innerText = `${percent}%`;
    if (displayGoalName) displayGoalName.innerText = goalName;
    document.getElementById('goalCurrent').innerText = `${currentCurrency}${currentSavings.toFixed(2)}`;
    document.getElementById('goalTotal').innerText = `${currentCurrency}${goalAmount.toFixed(2)}`;
}

// Velocity Logic
function updateSpendVelocity(currentExpense) {
    const prevAverage = Math.max(100, currentExpense * 1.5 + 50);
    const ratio = currentExpense / prevAverage;
    
    const velocityStatus = document.querySelector('.velocity-status');
    const velocityDesc = document.querySelector('.velocity-desc');
    const velocityFill = document.querySelector('.velocity-bar-fill');
    
    if(!velocityStatus || !velocityFill) return;
    
    const widthPercentage = Math.min(100, Math.max(5, (ratio * 100) / 2));
    velocityFill.style.width = `${widthPercentage}%`;
    
    if (currentExpense < prevAverage) {
        const lessPercent = Math.round((1 - ratio) * 100);
        velocityStatus.className = 'velocity-status positive';
        velocityStatus.innerText = `${lessPercent}% Slower`;
        velocityDesc.innerText = `You are spending less than your average pace last month. Keep it up!`;
        velocityFill.style.background = 'var(--income)';
    } else {
        const morePercent = Math.round((ratio - 1) * 100);
        velocityStatus.className = 'velocity-status negative';
        velocityStatus.innerText = `${morePercent}% Faster`;
        velocityDesc.innerText = `You are spending money faster than your typical monthly pace.`;
        velocityFill.style.background = 'var(--expense)';
    }
}

function changeCurrency() {
    currentCurrency = currencySelector.value;
    localStorage.setItem('currency', currentCurrency);
    updateValues();
    renderTransactions();
}

function loadCurrency() {
    const savedCurrency = localStorage.getItem('currency') || '$';
    currentCurrency = savedCurrency;
    if (currencySelector) currencySelector.value = savedCurrency;
}

// Profile Modal Interactions
function openProfileModal() {
    userNameInput.value = userName;
    profileModal.showModal();

    if (useCustomPicture) {
        uploadPictureBtn.classList.add('active');
        useGeneratedAvatarBtn.classList.remove('active');
    } else {
        useGeneratedAvatarBtn.classList.add('active');
        uploadPictureBtn.classList.remove('active');
    }
}

function closeProfileModalFunc() {
    profileModal.close();
}

function saveProfileName() {
    const newName = userNameInput.value.trim();
    if (newName) {
        userName = newName;
        localStorage.setItem('userName', userName);
    }

    localStorage.setItem('useCustomPicture', useCustomPicture);
    if (useCustomPicture && profilePicture) {
        localStorage.setItem('profilePicture', profilePicture);
    }

    updateProfileAvatar();
    closeProfileModalFunc();
}

function updateProfilePreview() {
    if (useCustomPicture && profilePicture) {
        profilePreview.src = profilePicture;
    } else {
        const encodedName = encodeURIComponent(userName || 'User');
        profilePreview.src = `https://ui-avatars.com/api/?name=${encodedName}&background=059669&color=fff&bold=true&size=128`;
    }
}

function updateProfileAvatar() {
    if (useCustomPicture && profilePicture) {
        if(sidebarProfileAvatar) sidebarProfileAvatar.src = profilePicture;
        if(mobileProfileAvatar) mobileProfileAvatar.src = profilePicture;
    } else {
        const encodedName = encodeURIComponent(userName || 'User');
        const url = `https://ui-avatars.com/api/?name=${encodedName}&background=059669&color=fff&bold=true`;
        if(sidebarProfileAvatar) sidebarProfileAvatar.src = url;
        if(mobileProfileAvatar) mobileProfileAvatar.src = url;
    }
    if (sidebarProfileName) sidebarProfileName.innerText = userName;
    updateProfilePreview();
}

function handleUseGeneratedAvatar() {
    useCustomPicture = false;
    useGeneratedAvatarBtn.classList.add('active');
    uploadPictureBtn.classList.remove('active');
    updateProfilePreview();
}

function handleUploadPicture() {
    profilePictureInput.click();
}

function handlePictureUpload(e) {
    const file = e.target.files[0];
    if (file && file.type.startsWith('image/')) {
        const reader = new FileReader();
        reader.onload = (event) => {
            profilePicture = event.target.result;
            useCustomPicture = true;
            uploadPictureBtn.classList.add('active');
            useGeneratedAvatarBtn.classList.remove('active');
            updateProfilePreview();
        };
        reader.readAsDataURL(file);
    }
}

// Event Listeners
if (form) form.addEventListener('submit', addTransaction);
if (currencySelector) currencySelector.addEventListener('change', changeCurrency);

// Quick Income Event Listener
if (quickIncomeForm) {
    quickIncomeForm.addEventListener('submit', (e) => {
        e.preventDefault();
        if (quickIncomeAmount.value.trim() === '') return;

        const transaction = {
            id: generateID(),
            text: 'Quick Income',
            amount: +Math.abs(quickIncomeAmount.value)
        };

        transactions.push(transaction);
        renderTransactions();
        updateValues();
        updateLocalStorage();
        updateChart();

        quickIncomeAmount.value = '';
    });
}

// Statement Event Listener
if (saveStatementBtn) saveStatementBtn.addEventListener('click', saveStatementConfig);

// Goal Form Event Listener
if (goalForm) {
    goalForm.addEventListener('submit', (e) => {
        e.preventDefault();
        if (goalInputName.value.trim() === '' || goalInputAmount.value.trim() === '') return;
        
        goalName = goalInputName.value.trim();
        goalAmount = parseFloat(goalInputAmount.value);
        
        localStorage.setItem('goalName', goalName);
        localStorage.setItem('goalAmount', goalAmount);
        
        updateValues();
        
        const submitBtn = goalForm.querySelector('.submit-action');
        if (submitBtn) {
            const originalText = submitBtn.innerHTML;
            submitBtn.innerHTML = 'Saved <i class="fa-solid fa-check"></i>';
            setTimeout(() => { submitBtn.innerHTML = originalText; }, 2000);
        }
    });
}

// Profile
if (sidebarProfileTrigger) sidebarProfileTrigger.addEventListener('click', openProfileModal);
if (mobileProfileTrigger) mobileProfileTrigger.addEventListener('click', openProfileModal);
if (saveProfileBtn) saveProfileBtn.addEventListener('click', saveProfileName);
if (cancelProfileBtn) cancelProfileBtn.addEventListener('click', closeProfileModalFunc);
if (closeModalBtn) closeModalBtn.addEventListener('click', closeProfileModalFunc);
if (useGeneratedAvatarBtn) useGeneratedAvatarBtn.addEventListener('click', handleUseGeneratedAvatar);
if (uploadPictureBtn) uploadPictureBtn.addEventListener('click', handleUploadPicture);
if (profilePictureInput) profilePictureInput.addEventListener('change', handlePictureUpload);

// Click outside to close dialog
if (profileModal) {
    profileModal.addEventListener('click', (e) => {
        if (e.target === profileModal) {
            closeProfileModalFunc();
        }
    });
}

if (userNameInput) {
    userNameInput.addEventListener('input', () => {
        if (!useCustomPicture) {
            const encodedName = encodeURIComponent(userNameInput.value || 'User');
            profilePreview.src = `https://ui-avatars.com/api/?name=${encodedName}&background=059669&color=fff&bold=true&size=128`;
        }
    });
}

// Window resize listener to handle chart
window.addEventListener('resize', () => {
    if (document.getElementById('view-dashboard').classList.contains('active')) {
        updateChart();
    }
});

// App Startup
loadCurrency();
updateProfileAvatar();
init();
