// Cloud Functions de IA do estoque Dellalio.
//
// O Cérebro roda no Windows, onde o firebase_ai e o cloud_functions do
// Flutter não existem; ele chama estas funções pelo protocolo callable em
// HTTPS, com o token do usuário. A chamada ao Gemini usa as credenciais do
// próprio servidor (Vertex AI) — nenhuma chave de API no app.
//
// Deploy: `cd functions && npm install && firebase deploy --only functions:estoque`
// (plano Blaze e API Vertex AI ativa — já ativada em 2026-10-20).

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenAI, Type } = require("@google/genai");

// Mesma região das outras functions do projeto (e kRegiaoFunctions no app).
const REGIAO = "southamerica-east1";
// Ordem de preferência: o primeiro que existir no projeto é usado e fica
// guardado. O app pode pedir outro "gemini-*" (kModeloIA), que entra na frente.
const MODELOS = ["gemini-3.5-flash", "gemini-3-flash", "gemini-2.5-flash"];
const LOCAL_VERTEX = "global";

const opcoes = { region: REGIAO, timeoutSeconds: 150, memory: "1GiB" };

let _ia;
function ia() {
  if (!_ia) {
    _ia = new GoogleGenAI({
      vertexai: true,
      project: process.env.GCLOUD_PROJECT,
      location: LOCAL_VERTEX,
    });
  }
  return _ia;
}

function modeloDe(dados) {
  const m = dados && dados.modelo;
  return typeof m === "string" && /^gemini-[\w.\-]+$/.test(m) ? m : null;
}

function exigirLogin(req) {
  if (!req.auth) throw new HttpsError("unauthenticated", "Faça login.");
}

let modeloQueFunciona = null;

function modeloInexistente(e) {
  const t = `${e && (e.status || e.code || "")} ${e && e.message}`;
  return /404|NOT_FOUND|not found|does not exist|is not supported/i.test(t);
}

async function gerarJson({ modelo, sistema, partes, schema }) {
  const ordem = [...new Set([modeloQueFunciona, modelo, ...MODELOS].filter(Boolean))];
  let ultimo;
  for (const m of ordem) {
    try {
      const resp = await ia().models.generateContent({
        model: m,
        contents: [{ role: "user", parts: partes }],
        config: {
          systemInstruction: sistema,
          responseMimeType: "application/json",
          responseSchema: schema,
          temperature: 0,
        },
      });
      modeloQueFunciona = m;
      try {
        return JSON.parse(resp.text);
      } catch (e) {
        throw new HttpsError("internal", "A IA não devolveu JSON válido.");
      }
    } catch (e) {
      if (e instanceof HttpsError || !modeloInexistente(e)) throw e;
      console.warn(`Modelo ${m} indisponível, tentando o próximo.`);
      ultimo = e;
    }
  }
  throw new HttpsError("unavailable", `Nenhum modelo Gemini disponível: ${ultimo && ultimo.message}`);
}

function parteArquivo(dados) {
  if (!dados.arquivoBase64 || !dados.mimeType) {
    throw new HttpsError("invalid-argument", "Arquivo ausente.");
  }
  if (dados.mimeType.startsWith("text/")) {
    return { text: Buffer.from(dados.arquivoBase64, "base64").toString("utf8") };
  }
  return { inlineData: { mimeType: dados.mimeType, data: dados.arquivoBase64 } };
}

// ---------------------------------------------------------------- lista

const SCHEMA_LISTA = {
  type: Type.OBJECT,
  properties: {
    clienteNome: { type: Type.STRING, nullable: true },
    projetoNome: { type: Type.STRING, nullable: true },
    itens: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          descricao: { type: Type.STRING },
          refFornecedor: { type: Type.STRING, nullable: true },
          fornecedorNome: { type: Type.STRING, nullable: true },
          categoria: {
            type: Type.STRING,
            nullable: true,
            enum: ["chapa", "sobra", "fita", "ferragem", "acessorio", "insumo"],
          },
          quantidade: { type: Type.NUMBER },
          unidade: { type: Type.STRING },
          larguraMm: { type: Type.NUMBER, nullable: true },
          alturaMm: { type: Type.NUMBER, nullable: true },
          espessuraMm: { type: Type.NUMBER, nullable: true },
          custoUnitario: { type: Type.NUMBER, nullable: true },
        },
        required: ["descricao", "quantidade", "unidade"],
      },
    },
  },
  required: ["itens"],
};

const SISTEMA_LISTA = `Você lê listas de compras e de corte de marcenaria (geralmente geradas pelo DinaBox, plugin do SketchUp).
Extraia cada ITEM DE COMPRA: chapas (MDF, MDP, compensado), sobras, fitas de borda, ferragens (dobradiças, corrediças, puxadores), acessórios e insumos.
Regras:
- NÃO liste peças cortadas individualmente quando houver totais por material; use os totais.
- Mantenha a descrição EXATAMENTE como está no documento.
- Traga a referência/código do fornecedor quando houver.
- Traga a unidade exatamente como aparece (ch, chapa, m², m, ml, un, pç, par, cx...).
- Use ponto como separador decimal nos números.
- Ignore totais, subtotais, custos gerais, cabeçalhos e rodapés.
- Identifique o cliente e o projeto/ambiente se constarem no documento.`;

exports.lerListaComIA = onCall(opcoes, async (req) => {
  exigirLogin(req);
  return gerarJson({
    modelo: modeloDe(req.data),
    sistema: SISTEMA_LISTA,
    partes: [parteArquivo(req.data), { text: "Extraia a lista no JSON pedido." }],
    schema: SCHEMA_LISTA,
  });
});

// ----------------------------------------------------------------- nota

const SCHEMA_NOTA = {
  type: Type.OBJECT,
  properties: {
    chaveAcesso: { type: Type.STRING, nullable: true },
    cnpjEmitente: { type: Type.STRING, nullable: true },
    nomeEmitente: { type: Type.STRING, nullable: true },
    numero: { type: Type.STRING, nullable: true },
    emitidaEm: { type: Type.STRING, nullable: true },
    itens: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          codigo: { type: Type.STRING, nullable: true },
          descricao: { type: Type.STRING },
          quantidade: { type: Type.NUMBER },
          unidade: { type: Type.STRING },
          valorUnitario: { type: Type.NUMBER, nullable: true },
        },
        required: ["descricao", "quantidade", "unidade"],
      },
    },
  },
  required: ["itens"],
};

const SISTEMA_NOTA = `Você lê DANFEs (nota fiscal eletrônica brasileira) em PDF ou foto.
Extraia: chave de acesso (44 dígitos, só números), CNPJ e nome do emitente, número da nota, data de emissão (ISO 8601) e cada item (código do produto, descrição exata, quantidade, unidade comercial e valor unitário).
Use ponto como separador decimal. Se um campo não estiver legível, devolva null.`;

exports.lerNotaComIA = onCall(opcoes, async (req) => {
  exigirLogin(req);
  return gerarJson({
    modelo: modeloDe(req.data),
    sistema: SISTEMA_NOTA,
    partes: [parteArquivo(req.data), { text: "Extraia a nota no JSON pedido." }],
    schema: SCHEMA_NOTA,
  });
});

// ------------------------------------------------- colunas de planilha

const COLUNAS = [
  "descricao", "quantidade", "unidade", "referencia", "fornecedor",
  "largura", "altura", "espessura", "custo",
];

exports.mapearColunasComIA = onCall(opcoes, async (req) => {
  exigirLogin(req);
  const linhas = Array.isArray(req.data.linhas) ? req.data.linhas.slice(0, 15) : [];
  const colunas = {};
  for (const c of COLUNAS) colunas[c] = { type: Type.INTEGER, nullable: true };
  return gerarJson({
    modelo: modeloDe(req.data),
    sistema:
      "Você recebe as primeiras linhas de uma planilha de lista de compras de marcenaria. " +
      "Descubra qual coluna (índice a partir de 0) contém cada campo e qual linha é o cabeçalho " +
      "(-1 se não houver). Use null para campos ausentes.",
    partes: [{ text: JSON.stringify(linhas) }],
    schema: {
      type: Type.OBJECT,
      properties: {
        linhaCabecalho: { type: Type.INTEGER },
        colunas: { type: Type.OBJECT, properties: colunas },
      },
      required: ["linhaCabecalho", "colunas"],
    },
  });
});

// ------------------------------------------------ desempate do casamento

exports.desempatarComIA = onCall(opcoes, async (req) => {
  exigirLogin(req);
  const itens = Array.isArray(req.data.itens) ? req.data.itens.slice(0, 80) : [];
  return gerarJson({
    modelo: modeloDe(req.data),
    sistema:
      "Você casa itens de listas de compras de marcenaria com materiais do estoque. " +
      "Para cada item, escolha entre os candidatos o materialId que é o MESMO produto " +
      "(mesma espessura, medida, cor/padrão e tipo) ou null se nenhum for. " +
      "Espessura ou medida diferente NUNCA é o mesmo produto. " +
      "Dê a confiança de 0 a 1.",
    partes: [{ text: JSON.stringify(itens) }],
    schema: {
      type: Type.OBJECT,
      properties: {
        respostas: {
          type: Type.ARRAY,
          items: {
            type: Type.OBJECT,
            properties: {
              indice: { type: Type.INTEGER },
              materialId: { type: Type.STRING, nullable: true },
              confianca: { type: Type.NUMBER },
            },
            required: ["indice", "confianca"],
          },
        },
      },
      required: ["respostas"],
    },
  });
});
