let coinDisplay = document.querySelector('.coins-cost');
let parsedCoin = parseFloat(coinDisplay.innerHTML);

let clickerCost = document.querySelector('.clicker-cost');
let parsedClickerCost = parseFloat(clickerCost.innerHTML);

let imgBeans = document.querySelector('.img-Beans');

// função para fazer a imagem mudar e gerar dinheiro ao click
function incrementCoin() {
    //adicionar o dinheiro
    parsedCoin += 1;
    coinDisplay.innerHTML = parsedCoin;
//troca de imagem
    imgBeans.src = "images/BeansMining.png";

   //cronometro para a imagem voltar
    setTimeout(() => {
        imgBeans.src = "images/BeansIdle.png";
    }, 120); 
}

function buyClicker() {
    if (parsedCoin >= parsedClickerCost) {
        parsedCoin -= parsedClickerCost;
        coinDisplay.innerHTML = parsedCoin;
        //
        let novoBean = document.createElement('img');
        novoBean.classList.add('mini-bean');
        novoBean.src = "images/BeansIdle.png";
        novoBean.style.top = Math.random() * 80 + "vh";
        novoBean.style.left = Math.random() * 80 + "vw";
        novoBean.setAttribute('draggable', 'false');
        document.body.appendChild(novoBean);
        ativarMiniBean(novoBean);
        fazerArrastavel(novoBean);
        //
    } else {
        // aviso de pobreza
        alert("Beanscoins insuficientes para comprar o Clicker!"); 
    }
}

//função para fazer o bean pequeno aparecer aleatoriamente na tela
function ativarMiniBean(novoBean){
    setInterval(() => {
        parsedCoin += 0.5;
        coinDisplay.innerHTML = parsedCoin;

        novoBean.src = "images/BeansMining.png";
        setTimeout(() =>{
            novoBean.src = "images/BeansIdle.png";
        }, 100) ; 
    }, 1000); 
}

//função para fazer os items serem arrastaveis
function fazerArrastavel(elemento) {
    let arrastando = false;
    let offsetX, offsetY;

    elemento.addEventListener('mousedown', (e) => {
        arrastando = true;
        offsetX = e.clientX - elemento.getBoundingClientRect().left;
        offsetY = e.clientY - elemento.getBoundingClientRect().top;
        elemento.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', (e) => {
        if (arrastando) {
            elemento.style.left = (e.clientX - offsetX) + 'px';
            elemento.style.top = (e.clientY - offsetY) + 'px';
        }
    });

    document.addEventListener('mouseup', () => {
        arrastando = false;
        elemento.style.cursor = 'grab';
    });
}